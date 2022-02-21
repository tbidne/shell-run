-- | Provides the 'ShellT' monad transformer.
--
-- @since 0.1.0.0
module ShellRun.ShellT
  ( ShellT (..),
  )
where

import Control.Concurrent qualified as CC
import Control.Exception.Safe (SomeException)
import Control.Exception.Safe qualified as SafeEx
import Control.Monad qualified as M
import Control.Monad.Catch (MonadCatch, MonadMask, MonadThrow)
import Control.Monad.IO.Unlift (MonadUnliftIO (..))
import Control.Monad.Loops qualified as Loops
import Data.IORef (IORef)
import Data.IORef qualified as IORef
import Data.Text qualified as T
import ShellRun.Class.MonadShell (MonadShell (..))
import ShellRun.Class.MonadTime (MonadTime (..))
import ShellRun.Command (Command (..))
import ShellRun.Data.InfNum (PosInfNum (..))
import ShellRun.Data.NonEmptySeq (NonEmptySeq)
import ShellRun.Data.TimeRep qualified as TimeRep
import ShellRun.Data.Timeout (Timeout (..))
import ShellRun.Env
  ( CmdLogging (..),
    Env (..),
    HasCmdDisplay (..),
    HasCmdLogging (..),
    HasCmdNameTrunc (..),
    HasFileLogging (..),
    HasTimeout (..),
  )
import ShellRun.Env.Types (HasCmdLineTrunc (..))
import ShellRun.IO (Stderr (..))
import ShellRun.IO qualified as ShIO
import ShellRun.Legend (LegendErr, LegendMap)
import ShellRun.Legend qualified as Legend
import ShellRun.Logging.Formatting qualified as LFormat
import ShellRun.Logging.Log (Log (..), LogDest (..), LogLevel (..), LogMode (..))
import ShellRun.Logging.Queue (LogText (..), LogTextQueue)
import ShellRun.Logging.Queue qualified as Queue
import ShellRun.Logging.RegionLogger (RegionLogger (..))
import ShellRun.Prelude
import ShellRun.Utils qualified as U
import System.Clock (Clock (..))
import System.Clock qualified as C
import System.Console.Regions (ConsoleRegion, RegionLayout (..))
import System.Console.Regions qualified as Regions
import System.Directory (XdgDirectory (..))
import System.Directory qualified as Dir
import UnliftIO qualified
import UnliftIO.Async qualified as UAsync

-- | `ShellT` is the main application type that runs shell commands.
--
-- @since 0.1.0.0
type ShellT :: Type -> (Type -> Type) -> Type -> Type
newtype ShellT env m a = MkShellT
  { -- | @since 0.1.0.0
    runShellT :: ReaderT env m a
  }
  deriving
    ( -- | @since 0.1.0.0
      Functor,
      -- | @since 0.1.0.0
      Applicative,
      -- | @since 0.1.0.0
      Monad,
      -- | @since 0.1.0.0
      MonadReader env,
      -- | @since 0.1.0.0
      MonadCatch,
      -- | @since 0.1.0.0
      MonadIO,
      -- | @since 0.1.0.0
      MonadMask,
      -- | @since 0.1.0.0
      MonadTime,
      -- | @since 0.1.0.0
      MonadThrow,
      -- | @since 0.1.0.0
      MonadUnliftIO
    )
    via (ReaderT env m)
  deriving
    ( -- | @since 0.1.0.0
      MonadTrans
    )
    via (ReaderT env)

-- | @since 0.1.0.0
instance
  ( HasCmdDisplay env,
    HasCmdNameTrunc env,
    HasCmdLineTrunc env,
    HasFileLogging env,
    MonadIO m
  ) =>
  RegionLogger (ShellT env m)
  where
  type Region (ShellT env m) = ConsoleRegion

  putLog :: Log -> ShellT env m ()
  putLog log = do
    maybeSendLogToQueue log
    maybePrintLog (liftIO . putStrLn) log

  putRegionLog :: ConsoleRegion -> Log -> ShellT env m ()
  putRegionLog region lg@MkLog {mode} = do
    let logFn = case mode of
          Set -> Regions.setConsoleRegion
          Append -> Regions.appendConsoleRegion
          Finish -> Regions.finishConsoleRegion

    maybeSendLogToQueue lg
    maybePrintLog (liftIO . logFn region) lg

maybePrintLog ::
  ( HasCmdDisplay env,
    HasCmdNameTrunc env,
    HasCmdLineTrunc env,
    MonadReader env m
  ) =>
  (Text -> m ()) ->
  Log ->
  m ()
maybePrintLog fn log@MkLog {dest} = do
  case dest of
    LogFile -> pure ()
    _ -> LFormat.formatConsoleLog log >>= fn

-- | @since 0.1.0.0
instance (MonadIO m, MonadMask m, MonadUnliftIO m) => MonadShell (ShellT Env m) where
  getDefaultDir :: ShellT Env m FilePath
  getDefaultDir = liftIO $ Dir.getXdgDirectory XdgConfig "shell-run"

  legendPathToMap :: FilePath -> ShellT Env m (Either LegendErr LegendMap)
  legendPathToMap = liftIO . Legend.legendPathToMap

  runCommands :: NonEmptySeq Command -> ShellT Env m ()
  runCommands commands = Regions.displayConsoleRegions $
    UAsync.withAsync maybePollQueue $ \fileLogger -> do
      start <- liftIO $ C.getTime Monotonic
      let actions = UAsync.mapConcurrently_ runCommand commands
          actionsWithTimer = UAsync.race_ actions counter

      result :: Either SomeException () <- UnliftIO.withRunInIO $ \runner -> SafeEx.try $ runner actionsWithTimer

      UAsync.cancel fileLogger

      Regions.withConsoleRegion Linear $ \r -> do
        case result of
          Left ex -> do
            let errMsg =
                  T.pack $
                    "Encountered an exception. This is likely not an error in any of the "
                      <> "commands run but rather an error in ShellRun itself: "
                      <> SafeEx.displayException ex
                fatalLog =
                  MkLog
                    { cmd = Nothing,
                      msg = errMsg,
                      lvl = Fatal,
                      mode = Finish,
                      dest = LogBoth
                    }
            putRegionLog r fatalLog
          Right _ -> pure ()

        end <- liftIO $ C.getTime Monotonic
        let totalTime = U.diffTime start end
            totalTimeTxt = "Finished! Total time elapsed: " <> TimeRep.formatTime totalTime
            finalLog =
              MkLog
                { cmd = Nothing,
                  msg = totalTimeTxt,
                  lvl = InfoBlue,
                  mode = Finish,
                  dest = LogBoth
                }

        putRegionLog r finalLog

        fileLogging <- asks getFileLogging
        case fileLogging of
          Nothing -> pure ()
          Just (fp, queue) -> Queue.flushQueue queue >>= traverse_ (logFile fp)

runCommand ::
  ( HasCmdDisplay env,
    HasCmdLogging env,
    HasCmdNameTrunc env,
    HasCmdLineTrunc env,
    HasFileLogging env,
    MonadIO m,
    MonadMask m,
    MonadUnliftIO m
  ) =>
  Command ->
  ShellT env m ()
runCommand cmd = do
  cmdLogging <- asks getCmdLogging
  fileLogging <- asks getFileLogging

  -- 1.    No CmdLogging and no FileLogging: No streaming at all.
  -- 2.    No CmdLogging and FileLogging: Stream (to file) but no console
  --       region.
  -- 3, 4. CmdLogging: Stream and create the region. FileLogging is globally
  --       enabled/disabled, so no need for a separate function. That is,
  --       tryTimeShStreamNoRegion and tryTimeShStreamRegion handle file
  --       logging automatically.
  res <- case (cmdLogging, fileLogging) of
    (Disabled, Nothing) -> liftIO $ ShIO.tryTimeSh cmd
    (Disabled, Just (_, _)) -> ShIO.tryTimeShStreamNoRegion cmd
    _ -> ShIO.tryTimeShStreamRegion cmd

  Regions.withConsoleRegion Linear $ \r -> do
    let (msg', lvl', t') = case res of
          Left (t, MkStderr err) -> (err, Error, t)
          Right t -> ("Success", InfoSuccess, t)
    putRegionLog r $
      MkLog
        { cmd = Just cmd,
          msg = msg' <> ". Time elapsed: " <> TimeRep.formatTime t',
          lvl = lvl',
          mode = Finish,
          dest = LogBoth
        }

counter ::
  ( HasTimeout env,
    MonadMask m,
    MonadReader env m,
    MonadIO m,
    RegionLogger m,
    Region m ~ ConsoleRegion
  ) =>
  m ()
counter = do
  -- This brief delay is so that our timer starts "last" i.e. after each individual
  -- command. This way the running timer console region is below all the commands'
  -- in the console.
  liftIO $ CC.threadDelay 100_000
  Regions.withConsoleRegion Linear $ \r -> do
    timeout <- asks getTimeout
    timer <- liftIO $ IORef.newIORef 0
    Loops.whileM_ (keepRunning r timer timeout) $ do
      elapsed <- liftIO $ do
        CC.threadDelay 1_000_000
        IORef.modifyIORef' timer (+ 1)
        IORef.readIORef timer
      logCounter r elapsed

logCounter ::
  ( RegionLogger m,
    Region m ~ ConsoleRegion
  ) =>
  ConsoleRegion ->
  Natural ->
  m ()
logCounter region elapsed = do
  let lg =
        MkLog
          { cmd = Nothing,
            msg = "Running time: " <> TimeRep.formatTime elapsed,
            lvl = InfoCyan,
            mode = Set,
            dest = LogConsole
          }
  putRegionLog region lg

keepRunning ::
  ( MonadIO m,
    RegionLogger m,
    Region m ~ ConsoleRegion
  ) =>
  ConsoleRegion ->
  IORef Natural ->
  Timeout ->
  m Bool
keepRunning region timer mto = do
  elapsed <- liftIO $ IORef.readIORef timer
  if timedOut elapsed mto
    then do
      putRegionLog region $
        MkLog
          { cmd = Nothing,
            msg = "Timed out, cancelling remaining tasks.",
            lvl = Warn,
            mode = Finish,
            dest = LogBoth
          }
      pure False
    else pure True

timedOut :: Natural -> Timeout -> Bool
timedOut _ (MkTimeout PPosInf) = False
timedOut timer (MkTimeout (PFin t)) = timer > t

maybeSendLogToQueue ::
  ( HasFileLogging env,
    MonadIO m
  ) =>
  Log ->
  ShellT env m ()
maybeSendLogToQueue log@MkLog {dest} =
  case dest of
    LogConsole -> pure ()
    _ -> do
      fileLogging <- asks getFileLogging
      case fileLogging of
        Nothing -> pure ()
        Just (_, queue) -> do
          Queue.writeQueue queue log

maybePollQueue :: (HasFileLogging env, MonadIO m) => ShellT env m ()
maybePollQueue = do
  fileLogging <- asks getFileLogging
  case fileLogging of
    Nothing -> pure ()
    Just (fp, queue) -> writeQueueToFile fp queue

writeQueueToFile :: MonadIO m => FilePath -> LogTextQueue -> m void
writeQueueToFile fp queue = M.forever $ Queue.readQueue queue >>= traverse_ (logFile fp)

logFile :: MonadIO m => FilePath -> LogText -> m ()
logFile fp = liftIO . appendFileUtf8 fp . unLogText
