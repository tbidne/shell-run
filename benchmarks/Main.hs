module Main (main) where

import Control.DeepSeq (force)
import Shrun.Configuration.Env (makeEnvAndShrun)
import Shrun.Prelude
import System.Environment (withArgs)
import Test.Tasty.Bench
  ( Benchmark,
    bench,
    bgroup,
    defaultMain,
    nfIO,
  )

main :: IO ()
main =
  do
    defaultMain
      [ noLogs,
        basicLogs,
        cmdLogs,
        fileLogs
      ]
    `finally` deleteIfExists "bench.log"

noLogs :: Benchmark
noLogs = bgroup "No Logging" (runLoops ["-d", "--no-config"])

basicLogs :: Benchmark
basicLogs = bgroup "Basic Logging" (runLoops ["--no-config"])

cmdLogs :: Benchmark
cmdLogs = bgroup "Command Logging" (runLoops ["-l", "--no-config"])

fileLogs :: Benchmark
fileLogs = bgroup "File Logging" (runLoops ["-f", "bench.log", "--no-config"])

runLoops :: List String -> List Benchmark
runLoops args = fmap f loops
  where
    f (!desc, !cmd) =
      run desc (cmd : args)

run :: String -> List String -> Benchmark
run desc args =
  bench desc $ nfIO $ withArgs args makeEnvAndShrun

loops :: List (String, String)
loops =
  force
    [ ("10_000", bashLoop "10000"),
      ("100_000", bashLoop "100000"),
      ("1_000_000", bashLoop "1000000")
    ]

bashLoop :: String -> String
bashLoop bound = "for i in {1.." ++ bound ++ "}; do echo ${i}; done"
