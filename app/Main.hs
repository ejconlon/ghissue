module Main where

import Control.Monad(sequence_)
import Github.Auth
import Github.Issues
import Ghissue
import Ghissue.Command.Show
import Ghissue.Command.New
import Ghissue.Command.Close
import Ghissue.Command.Label

commands :: [Command]
commands = [showCommand, newCommand, closeCommand, labelCommand]

main :: IO ()
main = do
  conf <- readConfig
  toAction conf commands
