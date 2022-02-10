-- | Provides the 'Timeout' type.
module ShellRun.Data.Timeout
  ( Timeout (..),
  )
where

import Refined (NonNegative, Refined)
import ShellRun.Prelude

-- | Represents a timeout, which is a non-negative integer.
newtype Timeout = MkTimeout
  {unTimeout :: Refined NonNegative Int}
  deriving (Eq, Ord, Show)