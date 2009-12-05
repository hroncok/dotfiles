-----------------------------------------------------------------------------
-- |
-- Module      :  XMonad.Actions.WorkspaceNames
-- Copyright   :  (c) Tomas Janousek <tomi@nomi.cz>
-- License     :  BSD3-style (see LICENSE)
--
-- Maintainer  :  Tomas Janousek <tomi@nomi.cz>
-- Stability   :  experimental
-- Portability :  unportable
--
-- Provides bindings to rename workspaces, show these names in DynamicLog and
-- swap workspaces along with their names. These names survive restart.
-- Together with "XMonad.Layout.WorkspaceDir" this provides for a fully
-- dynamic topic space workflow.
--
-----------------------------------------------------------------------------

{-# LANGUAGE DeriveDataTypeable #-}

module XMonad.Actions.WorkspaceNames (
    -- * Usage
    -- $usage

    -- * Workspace naming
    renameWorkspace,
    workspaceNamesPP,
    getWorkspaceNames,
    setWorkspaceName,
    setCurrentWorkspaceName,

    -- * Workspace swapping
    swapTo,
    swapWithCurrent,
    ) where

import XMonad
import qualified XMonad.StackSet as W
import qualified XMonad.Util.ExtensibleState as XS

import XMonad.Actions.CycleWS (findWorkspace, WSType(..), Direction1D(..))
import qualified XMonad.Actions.SwapWorkspaces as Swap
import XMonad.Hooks.DynamicLog (PP(..))
import XMonad.Prompt (showXPrompt, mkXPrompt, XPrompt, XPConfig)
import XMonad.Util.WorkspaceCompare (getSortByIndex)

import qualified Data.Map as M
import Data.Maybe (fromMaybe)

-- $usage
-- You can use this module with the following in your @~\/.xmonad\/xmonad.hs@ file:
--
-- > import XMonad.Actions.WorkspaceNames
--
-- Then add keybindings like the following:
--
-- >   , ((modm .|. shiftMask, xK_r      ), renameWorkspace defaultXPConfig)
--
-- and apply workspaceNamesPP to your DynamicLog pretty-printer:
--
-- > myLogHook =
-- >     workspaceNamesPP xmobarPP >>= dynamicLogString >>= xmonadPropLog
--
-- We also provide a modification of "XMonad.Actions.SwapWorkspaces"\'s
-- functionality, which may be used this way:
--
-- >   , ((modMask .|. shiftMask, xK_Left  ), swapTo Prev)
-- >   , ((modMask .|. shiftMask, xK_Right ), swapTo Next)
--
-- > [((modm .|. controlMask, k), swapWithCurrent i)
-- >     | (i, k) <- zip workspaces [xK_1 ..]]
--
-- For detailed instructions on editing your key bindings, see
-- "XMonad.Doc.Extending#Editing_key_bindings".



-- | Workspace names container.
newtype WorkspaceNames = WorkspaceNames (M.Map WorkspaceId String)
    deriving (Typeable, Read, Show)

instance ExtensionClass WorkspaceNames where
    initialValue = WorkspaceNames M.empty
    extensionType = PersistentExtension

-- | Returns a function that maps workspace tag @\"t\"@ to @\"t:name\"@ for
-- workspaces with a name, and to @\"t\"@ otherwise.
getWorkspaceNames :: X (WorkspaceId -> String)
getWorkspaceNames = do
    WorkspaceNames map <- XS.get
    return $ \wks -> case M.lookup wks map of
        Nothing -> wks
        Just s  -> wks ++ ":" ++ s

-- | Sets the name of a workspace. Empty string makes the workspace unnamed
-- again.
setWorkspaceName :: WorkspaceId -> String -> X ()
setWorkspaceName id name = do
    WorkspaceNames map <- XS.get
    XS.put $ WorkspaceNames $ if null name then M.delete id map else M.insert id name map
    refresh

-- | Sets the name of the current workspace. See 'setWorkspaceName'.
setCurrentWorkspaceName :: String -> X ()
setCurrentWorkspaceName name = do
    current <- gets (W.currentTag . windowset)
    setWorkspaceName current name

data Wor = Wor String
instance XPrompt Wor where
    showXPrompt (Wor x) = x

-- | Prompt for a new name for the current workspace and set it.
renameWorkspace :: XPConfig -> X ()
renameWorkspace conf = do
    mkXPrompt pr conf (const (return [])) setCurrentWorkspaceName
    where pr = Wor "Workspace name: "

-- | Modify "XMonad.Hooks.DynamicLog"\'s pretty-printing format to show
-- workspace names as well.
workspaceNamesPP :: PP -> X PP
workspaceNamesPP pp = do
    names <- getWorkspaceNames
    return $
        pp {
            ppCurrent         = ppCurrent         pp . names,
            ppVisible         = ppVisible         pp . names,
            ppHidden          = ppHidden          pp . names,
            ppHiddenNoWindows = ppHiddenNoWindows pp . names,
            ppUrgent          = ppUrgent          pp . names
        }



-- | See 'XMonad.Actions.SwapWorkspaces.swapTo'. This is the same with names.
swapTo :: Direction1D -> X ()
swapTo dir = do
    findWorkspace getSortByIndex dir AnyWS 1 >>= swapWithCurrent

-- | See 'XMonad.Actions.SwapWorkspaces.swapWithCurrent'. This is almost the
-- same with names.
swapWithCurrent :: WorkspaceId -> X ()
swapWithCurrent t = do
    current <- gets (W.currentTag . windowset)
    swapNames t current
    windows $ Swap.swapWorkspaces t current

-- | Swap names of the two workspaces.
swapNames :: WorkspaceId -> WorkspaceId -> X ()
swapNames id1 id2 = do
    WorkspaceNames map <- XS.get
    let getname id = fromMaybe "" $ M.lookup id map
        set id name map' = if null name then M.delete id map' else M.insert id name map'
    XS.put $ WorkspaceNames $ set id1 (getname id2) $ set id2 (getname id1) $ map
