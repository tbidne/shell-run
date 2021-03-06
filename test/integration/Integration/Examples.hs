module Integration.Examples (specs) where

import Integration.Prelude
import Integration.Utils (makeEnvAndVerify, _MkConfigIO)
import Shrun.Configuration.Env.Types
  ( CmdDisplay (..),
    CmdLogging (..),
    StripControl (..),
  )
import Shrun.Data.NonEmptySeq qualified as NESeq

specs :: TestTree
specs =
  testGroup
    "Examples"
    [ examplesConfig,
      examplesDefault
    ]

examplesConfig :: TestTree
examplesConfig =
  testCase "examples/config.toml is valid" $
    do
      makeEnvAndVerify
        ["-c", "examples/config.toml", "cmd"]
        (view _MkConfigIO)
        (Just 20)
        (Just ())
        StripControlAll
        Enabled
        ShowKey
        (Just 80)
        (Just 0)
        StripControlSmart
        False
        (NESeq.singleton "cmd")

examplesDefault :: TestTree
examplesDefault = testCase "examples/default.toml is valid" $ do
  makeEnvAndVerify
    ["-c", "examples/default.toml", "cmd"]
    (view _MkConfigIO)
    Nothing
    Nothing
    StripControlAll
    Disabled
    ShowKey
    Nothing
    Nothing
    StripControlSmart
    False
    (NESeq.singleton "cmd")
