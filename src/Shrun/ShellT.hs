{-# LANGUAGE UndecidableInstances #-}

-- | Provides the 'ShellT' monad transformer.
--
-- @since 0.1
module Shrun.ShellT
  ( ShellT,
    runShellT,
  )
where

import Shrun.Configuration.Env.Types (Env)
import Shrun.Effects.FileSystemReader (FileSystemReader (..))
import Shrun.Effects.FileSystemWriter (FileSystemWriter (..))
import Shrun.Effects.Mutable
import Shrun.Effects.Process (Process (..))
import Shrun.Effects.Terminal (Terminal (..))
import Shrun.Effects.Timing (Timing (..))
import Shrun.IO qualified as ShIO
import Shrun.Logging.RegionLogger (RegionLogger (..))
import Shrun.Logging.Types (LogMode (..))
import Shrun.Prelude
import System.Console.Regions (ConsoleRegion)
import System.Console.Regions qualified as Regions

-- | `ShellT` is the main application type that runs shell commands.
--
-- @since 0.1
type ShellT :: Type -> (Type -> Type) -> Type -> Type
newtype ShellT env m a = MkShellT (ReaderT env m a)
  deriving
    ( -- | @since 0.1
      Functor,
      -- | @since 0.1
      Applicative,
      -- | @since 0.1
      Monad,
      -- | @since 0.1
      MonadReader env,
      -- | @since 0.1
      MonadCatch,
      -- | @since 0.5
      FileSystemReader,
      -- | @since 0.5
      FileSystemWriter,
      -- | @since 0.1
      MonadIO,
      -- | @since 0.1
      MonadMask,
      -- | @since 0.5
      Mutable,
      -- | @since 0.5
      Terminal,
      -- | @since 0.5
      Timing,
      -- | @since 0.1
      MonadThrow,
      -- | @since 0.1
      MonadUnliftIO
    )
    via (ReaderT env m)

-- | Runs a 'ShellT' with the given @env@.
--
-- @since 0.1
runShellT :: ShellT env m a -> env -> m a
runShellT (MkShellT rdr) = runReaderT rdr
{-# INLINEABLE runShellT #-}

-- Concrete Env here so we can vary our logging logic with other envs
-- (i.e. in tests).

-- | @since 0.1
instance (MonadIO m, MonadMask m, Terminal m) => RegionLogger (ShellT Env m) where
  type Region (ShellT Env m) = ConsoleRegion

  logFn = putTextLn

  logModeToRegionFn Set cr = liftIO . Regions.setConsoleRegion cr
  logModeToRegionFn Append cr = liftIO . Regions.appendConsoleRegion cr
  logModeToRegionFn Finish cr = liftIO . Regions.finishConsoleRegion cr

  withConsoleRegion = Regions.withConsoleRegion

-- | @since 0.3.0.1
instance
  (MonadMask m, MonadUnliftIO m, Mutable m, Terminal m, Timing m) =>
  Process (ShellT Env m)
  where
  tryCmd = ShIO.tryCommand
  tryCmdStream = ShIO.tryCommandStreamNoRegion
  tryCmdStreamRegion = ShIO.tryCommandStreamRegion
