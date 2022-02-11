{-# LANGUAGE UndecidableInstances #-}

-- | Provides the 'GoodMockShell' type.
module MockShell.GoodMockShell (GoodMockShell (..)) where

import Data.HashMap.Strict qualified as Map
import Data.String (String)
import MockEnv (MockEnv)
import MockShell.MockShellBase (MockShellBase (..))
import ShellRun.Class.MonadShell (MonadShell (..))
import ShellRun.Data.Command (Command (..))
import ShellRun.Data.Legend (LegendErr, LegendMap)
import ShellRun.Logging.RegionLogger (RegionLogger (..))
import ShellRun.Prelude

-- | 'GoodMockShell' is intended to test a \"Happy path\" run of
-- 'ShellRun.runShell'.
type GoodMockShell :: Type -> Type
newtype GoodMockShell a = MkGoodMockShell {runGoodMockShell :: MockShellBase a}
  deriving
    ( Functor,
      Applicative,
      Monad,
      MonadReader MockEnv,
      MonadWriter (List Text),
      RegionLogger
    )
    via MockShellBase

instance MonadShell GoodMockShell where
  legendPathToMap :: Text -> GoodMockShell (Either LegendErr LegendMap)
  legendPathToMap _ = pure $ Right mp
    where
      mp =
        Map.fromList
          [ ("cmd1", "command 1"),
            ("cmd2", "command 2"),
            ("both", "cmd1,,cmd2")
          ]

  runCommands :: List Command -> GoodMockShell ()
  runCommands = tell . fmap command

instance Show a => Show (GoodMockShell a) where
  show :: GoodMockShell a -> String
  show x = "MkGoodMockShell " <> show x
