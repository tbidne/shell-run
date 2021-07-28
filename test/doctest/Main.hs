module Main (main) where

import Test.DocTest qualified as DocTest

main :: IO ()
main =
  DocTest.doctest $
    [ "-isrc",
      "src/ShellRun/Math/NonNegative.hs",
      "src/ShellRun/Math/Positive.hs",
      "src/ShellRun/Parsing/Commands.hs",
      "src/ShellRun/Parsing/Legend/Internal.hs",
      "src/ShellRun/Utils/Internal.hs",
      "src/ShellRun/Utils.hs",
      "src/ShellRun/Utils/Text.hs"
    ] <> exts

exts :: [String]
exts =
  [ "-XDerivingVia",
    "-XFlexibleInstances",
    "-XImportQualifiedPost",
    "-XInstanceSigs",
    "-XLambdaCase",
    "-XMultiParamTypeClasses",
    "-XMultiWayIf",
    "-XNamedFieldPuns",
    "-XNumericUnderscores",
    "-XOverloadedStrings",
    "-XScopedTypeVariables",
    "-XStandaloneKindSignatures",
    "-XTupleSections",
    "-XTypeFamilies"
  ]
