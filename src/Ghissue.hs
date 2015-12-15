{-# LANGUAGE ExistentialQuantification #-}

module Ghissue (
  IssueRange(Issue, InclusiveRange),
  Config(..),
  Command(..),
  toAction,
  allIssues,
  contains,
  listContains,
  issuesReadM,
  readConfig,
  urlForIssue
) where

import Data.Char(isSpace)
import Data.List(concatMap)
import Data.List.Split(splitOn)
import Options.Applicative
import Options.Applicative.Types
import Control.Monad.Except
import Control.Monad.Reader

data IssueRange = Issue Int | InclusiveRange Int Int

allIssues :: [IssueRange] -> [Int]
allIssues irs = let
  toList (Issue i) = [i]
  toList (InclusiveRange s e) = [s..e]
  in concatMap toList irs

{-| Does an an IssueRange contain an issue
  >>> contains 1 (Issue 1)
  True
  >>> contains 1 (Issue 2)
  False
  >>> contains 1 (InclusiveRange 1 3)
  True
  >>> contains 3 (InclusiveRange 1 3)
  True
  >>> contains 4 (InclusiveRange 1 3)
  False
 -}
contains :: Int -> IssueRange -> Bool
contains x (Issue y) = x == y
contains x (InclusiveRange l u) = (l <= x) && (x <= u)

{-|Test an issue against a list of ranges. Empty list contains all
  >>> listContains 1 []
  True
  >>> listContains 2 [Issue 1]
  False
-}
listContains :: Int -> [IssueRange] -> Bool
listContains _ [] = True
listContains x irs = or (map (contains x) irs)

{-
  Read an list of IssueRanges
 -}
issuesReadM :: ReadM [IssueRange]
issuesReadM = let
  readm = do
    input <- ask
    let issuerangeStrs = splitOn "," input
    sequence (map (lift . parseRange) issuerangeStrs)
  in ReadM readm

err :: String -> Except ParseError a
err msg = throwError (ErrorMsg msg)

parseInt :: String -> Except ParseError Int
parseInt istr = let
  is = reads istr
  in if (length is /= 1)
     then err ("Could not parse int: " <> istr)
     else return (fst (is !! 0))

parseRange :: String -> Except ParseError IssueRange
parseRange range = let
  ranges = splitOn "-" range
  in case (length ranges) of 0 -> err ("failed to parse issue: " <> range)
                             1 -> fmap Issue (parseInt (ranges !! 0))
                             2 -> do
                                 low <- parseInt (ranges !! 0)
                                 high <- parseInt (ranges !! 1)
                                 return (InclusiveRange low high)
                             otherwise -> err ("too many - characters: " <> range)
{-
  This is any information we need to make a query
-}
data Config = Config { configAuth :: String, configGithubOrg :: String, configRepo :: String }

{-
 TODO this should look towards root for .git folder, then find the ghissues.conf in there
-}
readConfig :: IO Config
readConfig = do
  conf <- readFile ".ghissue.config"
  let [auth, org, repo'] = splitOn " " conf
  let repo = reverse (dropWhile isSpace (reverse repo'))
  return (Config auth org repo)

{-
 This is the struture we fit each subcommand into
 -}
data Command = forall a . Command {
  commandName :: String,
  commandDesc :: String,
  commandParser :: Parser a,
  commandAction :: Config -> a -> IO ()
}

{-
  Prepares the subcommand
-}
subcom conf Command { commandName = name, commandDesc = desc, commandParser = parser, commandAction = act } = let
  toAct = act conf
  actionParser = toAct <$> parser
  in command name (info actionParser (progDesc desc))

{-
  Called by the main function to run one of the commands
-}
toAction :: Config -> [Command] -> IO ()
toAction conf commands = let
  subcommands = map (subcom conf) commands
  subc = subparser (mconcat subcommands)
  in do
    action <- execParser (info subc idm)
    action

urlForIssue :: Config -> Int -> String
urlForIssue Config { configGithubOrg = org, configRepo = repo } id =
  "https://github.com/" ++ org ++ "/" ++ repo ++ "/issues/" ++ (show id)
