-- | Property tests for ShellRun.Utils.
module Props.ShellRun.Utils
  ( props,
  )
where

import Hedgehog (PropertyT)
import Hedgehog qualified as H
import MaxRuns (MaxRuns (..))
import Props.Generators qualified as PGens
import Refined qualified as R
import ShellRun.Data.TH qualified as TH
import ShellRun.Prelude
import ShellRun.Utils qualified as U
import Test.Tasty (TestTree)
import Test.Tasty qualified as T
import Test.Tasty.Hedgehog qualified as TH

-- | Entry point for ShellRun.Utils property tests.
props :: TestTree
props = T.testGroup "ShellRun.Utils" [diffTimeProps, divWithRemProps]

diffTimeProps :: TestTree
diffTimeProps = T.askOption $ \(MkMaxRuns limit) ->
  TH.testProperty "diffTime" $
    H.withTests limit $
      H.property $ do
        t1 <- H.forAll PGens.genTimeSpec
        t2 <- H.forAll PGens.genTimeSpec
        let result = U.diffTime t1 t2
        H.assert $ result >= TH.zeroNN

divWithRemProps :: TestTree
divWithRemProps = T.askOption $ \(MkMaxRuns limit) ->
  TH.testProperty "divWithRem" $
    H.withTests limit $
      H.property $ do
        nn <- H.forAll PGens.genNonNegative
        pos <- H.forAll PGens.genPositive
        let result = U.divWithRem nn pos
        vDivWithRem (nn, pos) result

vDivWithRem :: Tuple2 RNonNegative RPositive -> Tuple2 RNonNegative RNonNegative -> PropertyT IO ()
vDivWithRem (n, divisor) (e, remainder) = do
  H.assert $ (divisorRaw * eRaw) + remainderRaw == nRaw
  H.footnote $
    "("
      <> show divisorRaw
      <> " * "
      <> show eRaw
      <> ") + "
      <> show remainderRaw
      <> " == "
      <> show nRaw
  H.assert $ remainderRaw <= nRaw
  H.footnote $ show remainderRaw <> " <= " <> show nRaw
  where
    nRaw = R.unrefine n
    divisorRaw = R.unrefine divisor
    eRaw = R.unrefine e
    remainderRaw = R.unrefine remainder
