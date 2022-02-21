-- | Property tests for ShellRun.Logging.Formatting.
--
-- @since 0.1.0.0
module Props.ShellRun.Logging.Formatting
  ( props,
  )
where

import Data.Functor.Identity (Identity (..))
import Data.Text qualified as T
import Hedgehog (Gen, PropertyT)
import Hedgehog qualified as H
import Hedgehog.Gen qualified as HGen
import Hedgehog.Internal.Range qualified as HRange
import MaxRuns (MaxRuns (..))
import Props.ShellRun.Logging.Generators qualified as LGens
import ShellRun.Command (Command (..))
import ShellRun.Data.InfNum (PosInfNum (..))
import ShellRun.Env.Types
  ( CommandDisplay (..),
    HasCmdTruncation (..),
    HasCommandDisplay (..),
    HasLineTruncation (..),
    Truncation (..),
    TruncationArea (..),
  )
import ShellRun.Logging.Formatting qualified as Formatting
import ShellRun.Logging.Log
  ( Log (..),
    LogLevel (..),
  )
import ShellRun.Logging.Log qualified as Log
import ShellRun.Prelude
import Test.Tasty (TestTree)
import Test.Tasty qualified as T
import Test.Tasty.Hedgehog qualified as TH

-- | Entry point for ShellRun.Logging.Formatting property tests.
props :: TestTree
props =
  T.testGroup
    "ShellRun.Logging.Formatting"
    [ messageProps,
      prefixProps,
      displayCmdProps,
      displayKeyProps,
      cmdTruncProps,
      lineTruncProps
    ]

messageProps :: TestTree
messageProps = T.askOption $ \(MkMaxRuns limit) ->
  TH.testProperty "Includes message" $
    H.withTests limit $
      H.property $ do
        env <- H.forAll genEnv
        log@MkLog {msg} <- H.forAll LGens.genLog
        let result = runMockApp (Formatting.formatConsoleLog log) env
        H.annotate $ "Result: " <> T.unpack result
        H.assert $ msg `T.isInfixOf` result || "..." `T.isSuffixOf` result

prefixProps :: TestTree
prefixProps = T.askOption $ \(MkMaxRuns limit) ->
  TH.testProperty "Formats prefix" $
    H.withTests limit $
      H.property $ do
        env <- H.forAll genEnv
        log@MkLog {lvl} <- H.forAll LGens.genLog
        let result = runMockApp (Formatting.formatConsoleLog log) env
        H.annotate $ "Result: " <> T.unpack result
        case lvl of
          -- level is None: no prefix
          None -> foldr (noMatch result) (pure ()) nonEmptyPrefixes
          -- level is not None: includes prefix
          _ -> do
            let pfx = Log.levelToPrefix lvl
            H.annotate $ T.unpack pfx
            H.assert $ pfx `T.isInfixOf` result || "..." `T.isSuffixOf` result
  where
    nonEmptyPrefixes = [SubCommand .. Fatal]
    noMatch :: Text -> LogLevel -> PropertyT IO () -> PropertyT IO ()
    noMatch t level acc = do
      let pfx = Log.levelToPrefix level
      H.annotate $ T.unpack t
      H.annotate $ T.unpack pfx
      H.assert $ not (T.isInfixOf pfx t)
      acc

displayCmdProps :: TestTree
displayCmdProps = T.askOption $ \(MkMaxRuns limit) ->
  TH.testProperty "Displays command literal" $
    H.withTests limit $
      H.property $ do
        env <- H.forAll genEnvDispCmd
        log@MkLog {cmd = Just (MkCommand _ cmd')} <- H.forAll LGens.genLogWithCmd
        let result = runMockApp (Formatting.formatConsoleLog log) env
        H.annotate $ "Result: " <> T.unpack result
        H.assert $ cmd' `T.isInfixOf` result || "..." `T.isInfixOf` result

displayKeyProps :: TestTree
displayKeyProps = T.askOption $ \(MkMaxRuns limit) ->
  TH.testProperty "Displays command lkey" $
    H.withTests limit $
      H.property $ do
        env <- H.forAll genEnvDispKey
        log@MkLog {cmd = Just (MkCommand (Just key) _)} <- H.forAll LGens.genLogWithCmdKey
        let result = runMockApp (Formatting.formatConsoleLog log) env
        H.annotate $ "Result: " <> T.unpack result
        H.assert $ key `T.isInfixOf` result || "..." `T.isInfixOf` result

cmdTruncProps :: TestTree
cmdTruncProps = T.askOption $ \(MkMaxRuns limit) ->
  TH.testProperty "Truncates long command" $
    H.withTests limit $
      H.property $ do
        env <- H.forAll genEnvCmdTrunc
        cmd' <- MkCommand Nothing <$> H.forAll genLongCmdText
        log <- H.forAll LGens.genLog
        let log' = log {cmd = Just cmd'}
            result = runMockApp (Formatting.formatConsoleLog log') env
        H.annotate $ "Result: " <> T.unpack result
        H.assert $ "...]" `T.isInfixOf` result

lineTruncProps :: TestTree
lineTruncProps = T.askOption $ \(MkMaxRuns limit) ->
  TH.testProperty "Truncates long line" $
    H.withTests limit $
      H.property $ do
        env <- H.forAll genEnvLineTrunc
        msg' <- H.forAll genLongLineText
        log <- H.forAll LGens.genLog

        -- only perform line truncation for SubCommand (also requires a command)
        let log' = log {msg = msg', cmd = Just (MkCommand (Just "") ""), lvl = SubCommand}
            result = runMockApp (Formatting.formatConsoleLog log') env

        H.annotate $ "Result: " <> T.unpack result
        H.assert $ "..." `T.isSuffixOf` result
        H.diff result (\t l -> T.length t < l + colorLen) lineTruncLimit

-- Colorization adds chars that the shell interprets as color commands.
-- This affects the length, so if we do anything that tests the length
-- of a line, this needs to be taken into account.
--
-- The colorization looks like: \ESC[<digits>m ... \ESC[0m, where digit is up
-- to 3 chars. Strictly speaking, System.Console.Pretty only appears to use
-- two digit colors, i.e. 9 total, and in fact we passed 1,000,000 tests using
-- 9. Still, the standard mentions up to 3 digits, so we will use that, giving
-- a total of 10. More info:
-- https://en.wikipedia.org/wiki/ANSI_escape_code#3-bit_and_4-bit
colorLen :: Int
colorLen = 10

data Env = MkEnv
  { cmdDisplay :: CommandDisplay,
    cmdTrunc :: Truncation 'TCommand,
    lineTrunc :: Truncation 'TLine
  }
  deriving (Eq, Show)

genEnv :: Gen Env
genEnv =
  MkEnv
    <$> HGen.enumBounded
    <*> fmap MkTruncation genPPosInf
    <*> fmap MkTruncation genPPosInf

cmdTruncLimit :: Integral a => a
cmdTruncLimit = 30

genEnvCmdTrunc :: Gen Env
genEnvCmdTrunc =
  MkEnv
    <$> HGen.enumBounded
    <*> fmap (MkTruncation . PFin) genNat
    <*> pure (MkTruncation PPosInf)
  where
    genNat = HGen.integral range
    range = HRange.linear 0 cmdTruncLimit

genLongCmdText :: Gen Text
genLongCmdText = HGen.text range HGen.latin1
  where
    range = HRange.linearFrom (cmdTruncLimit + 1) (cmdTruncLimit + 1) 100

lineTruncLimit :: Integral a => a
lineTruncLimit = 80

genEnvLineTrunc :: Gen Env
genEnvLineTrunc =
  MkEnv
    <$> HGen.enumBounded
    <*> pure (MkTruncation PPosInf)
    <*> fmap (MkTruncation . PFin) genNat
  where
    genNat = HGen.integral range
    range = HRange.linear 0 lineTruncLimit

genLongLineText :: Gen Text
genLongLineText = HGen.text range HGen.latin1
  where
    range = HRange.linearFrom (lineTruncLimit + 1) (lineTruncLimit + 1) 120

genEnvDispCmd :: Gen Env
genEnvDispCmd =
  MkEnv ShowCommand
    <$> fmap MkTruncation genPPosInf
    <*> fmap MkTruncation genPPosInf

genEnvDispKey :: Gen Env
genEnvDispKey =
  MkEnv ShowKey
    <$> fmap MkTruncation genPPosInf
    <*> fmap MkTruncation genPPosInf

genPPosInf :: Gen (PosInfNum Natural)
genPPosInf = HGen.choice [fmap PFin genNat, pure PPosInf]
  where
    genNat = HGen.integral range
    range = HRange.exponential 0 100

runMockApp :: ReaderT env Identity a -> env -> a
runMockApp env = runIdentity . runReaderT env

instance HasCommandDisplay Env where
  getCommandDisplay = cmdDisplay

instance HasCmdTruncation Env where
  getCmdTruncation = cmdTrunc

instance HasLineTruncation Env where
  getLineTruncation = lineTrunc