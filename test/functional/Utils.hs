-- | Provides utilities.
module Utils
  ( -- * Logging messages
    cancelled,
    totalTime,

    -- * Logging color prefixes
    subCommandPrefix,
    infoSuccessPrefix,
    errPrefix,
  )
where

import ShellRun.Prelude

-- | Expected timeout 'Text'.
cancelled :: Text
cancelled = "Timed out, cancelling remaining tasks."

-- | Expected total \"Time elapsed\"" 'Text'.
totalTime :: Text
totalTime = "Finished! Total time elapsed: "

-- | Expected success 'Text'.
subCommandPrefix :: Text -> Text
subCommandPrefix txt = "[Command] " <> txt

-- | Expected success 'Text'.
infoSuccessPrefix :: Text -> Text
infoSuccessPrefix txt = "[Info] Successfully ran `" <> txt <> "`. Time elapsed:"

-- | Expected error 'Text'.
errPrefix :: Text -> Text
errPrefix txt = "[Error] Error running `" <> txt <> "`:"