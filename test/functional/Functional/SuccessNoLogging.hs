-- | Functional test for a successful run.
module Functional.SuccessNoLogging (spec) where

import Functional.Prelude
import Functional.Utils qualified as U
import Test.Tasty.HUnit qualified as THU

-- | Spec that should run commands successfully.
spec :: TestTree
spec =
  THU.testCase "Should run commands successfully without logging" $ do
    let argList = ["--cmd-log", "--disable-log"] <> commands

    results <- readIORef =<< U.runAndGetLogs argList

    [] @=? results
  where
    commands = ["sleep 1 && echo hi && sleep 2"]
