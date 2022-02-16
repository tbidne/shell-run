{-# OPTIONS_GHC -Wno-redundant-constraints #-}

-- | Provides the 'NonEmptySeq' type.
--
-- @since 0.1.0.0
module ShellRun.Data.NonEmptySeq
  ( -- * Type
    NonEmptySeq (..),

    -- * Construction
    singleton,

    -- * Elimination
    toSeq,
    toList,

    -- * Unsafe
    unsafeFromNonEmpty,
    unsafeFromList,
  )
where

import Data.List.NonEmpty (NonEmpty (..))
import Data.Sequence (Seq (..))
import GHC.Exts qualified as Exts
import GHC.Stack (HasCallStack)
import ShellRun.Prelude

-- $setup
-- >>> import GHC.Exts (fromList)

-- | Represents a non-empty sequence. This is useful for when we want a
-- non-empty and finite list.
--
-- @since 0.1.0.0
data NonEmptySeq a = a :|^ (Seq a)
  deriving stock
    ( -- | @since 0.1.0.0
      Eq,
      -- | @since 0.1.0.0
      Show
    )

infixr 5 :|^

-- | @since 0.1.0.0
instance Semigroup (NonEmptySeq a) where
  xs <> ys = unsafeFromSeq $ toSeq xs <> toSeq ys

-- | @since 0.1.0.0
instance Functor NonEmptySeq where
  fmap f = unsafeFromSeq . fmap f . toSeq

-- | @since 0.1.0.0
instance Applicative NonEmptySeq where
  pure x = x :|^ Empty
  f <*> xs = unsafeFromSeq $ toSeq f <*> toSeq xs

-- | @since 0.1.0.0
instance Monad NonEmptySeq where
  xs >>= f = unsafeFromSeq $ toSeq xs >>= (toSeq . f)

-- | @since 0.1.0.0
instance Foldable NonEmptySeq where
  foldMap f = foldMap f . toSeq

-- | @since 0.1.0.0
instance Traversable NonEmptySeq where
  traverse f = fmap unsafeFromSeq . traverse f . toSeq

-- | Creates a singleton 'NonEmptySeq'.
--
-- @since 0.1.0.0
singleton :: a -> NonEmptySeq a
singleton x = x :|^ Empty

-- | Exposes the underlying sequence.
--
-- ==== __Examples__
-- >>> toSeq (1 :|^ fromList [2,3,4])
-- fromList [1,2,3,4]
--
-- @since 0.1.0.0
toSeq :: NonEmptySeq a -> Seq a
toSeq (x :|^ xs) = x :<| xs

-- | 'NonEmptySeq' to list.
--
-- ==== __Examples__
-- >>> toList (1 :|^ fromList [2,3,4])
-- [1,2,3,4]
--
-- @since 0.1.0.0
toList :: NonEmptySeq a -> [a]
toList (x :|^ xs) = Exts.toList (x :<| xs)

-- | 'NonEmptySeq' from 'NonEmpty'. Unsafe in the sense that it does not
-- terminate for infinite 'NonEmpty'.
--
-- ==== __Examples__
-- >>> unsafeFromNonEmpty ( 1 :| [3,4])
-- 1 :|^ fromList [3,4]
--
-- @since 0.1.0.0
unsafeFromNonEmpty :: HasCallStack => NonEmpty a -> NonEmptySeq a
unsafeFromNonEmpty (x :| xs) = x :|^ Exts.fromList xs

-- | Even more unsafe than 'unsafeFromNonEmpty'; will throw an error on an
-- empty list.
--
-- ==== __Examples__
-- >>> unsafeFromList [1,2,3]
-- 1 :|^ fromList [2,3]
--
-- @since 0.1.0.0
unsafeFromList :: HasCallStack => List a -> NonEmptySeq a
unsafeFromList [] = error "[ShellRun.Data.NonEmptySeq] Empty list passed to unsafeFromList"
unsafeFromList (x : xs) = x :|^ Exts.fromList xs

unsafeFromSeq :: HasCallStack => Seq a -> NonEmptySeq a
unsafeFromSeq (x :<| xs) = x :|^ xs
unsafeFromSeq _ = error "[ShellRun.Data.NonEmptySeq] Empty seq passed to unsafeFromSeq"