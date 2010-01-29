{- |
Module      :  $Header$
Description :  add to all names in the nodes of the libenv a list of paths
Copyright   :  (c) Ewaryst Schulz DFKI Bremen 2010
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt
Maintainer  :  Ewaryst.Schulz@dfki.de
Stability   :  provisional
Portability :  non-portable(Logic)

the list of all paths by which the name is imported into a node is added
to the name. Additionally we keep the original name.
This pathification is used in the OMDoc facility.
-}

module Proofs.PathifyNames (pathifyLibEnv) where

import Logic.Coerce
import Logic.Comorphism
import Logic.Grothendieck
import Logic.Logic

import Static.DevGraph
import Static.GTheory
import Static.History

import Common.ExtSign
import Common.Id
import Common.LibName
import Common.Result

import Data.Graph.Inductive.Graph
import Data.List
import Data.Maybe
import qualified Data.Map as Map
import Control.Monad

pathifyLibEnv :: LibEnv -> Result LibEnv
pathifyLibEnv libEnv =
    foldM f Map.empty $ getTopsortedLibs libEnv
        where
          f le ln =
              do
                let dg0 = lookupDGraph ln libEnv
                dg <- pathifyDG (getLibId ln) dg0
                return $ Map.insert ln dg le


pathifyDG :: LibId -> DGraph -> Result DGraph
pathifyDG li dg = do
  foldM (pathifyLabNode li) dg $ topsortedNodes dg


pathifyLabNode :: LibId -> DGraph -> LNode DGNodeLab -> Result DGraph
pathifyLabNode li dg (n, lb) =
   if isDGRef lb then return dg else case dgn_theory lb of
    G_theory lid (ExtSign sig _) _ _ _ -> do
      -- the functions needed for the mapping:
      -- Map symbol [LinkPath symbol] -> Map G_symbol [LinkPath G_symbol]
      let f = G_symbol lid
      let h = map (fmap f)
      -- get the global imports
      innMorphs <- getGlobalImports lid $ innDG dg n
      m <- pathify lid li sig innMorphs
      let nlb = lb { dgn_symbolpathlist = Map.mapKeys f (Map.map h m) }
      return $ changesDGH dg [SetNodeLab lb (n, nlb)]

getGlobalImports :: forall lid sublogics
        basic_spec sentence symb_items symb_map_items
         sign morphism symbol raw_symbol proof_tree .
        Logic lid sublogics
         basic_spec sentence symb_items symb_map_items
          sign morphism symbol raw_symbol proof_tree =>
                   lid -> [LEdge DGLinkLab] -> Result [(Int, morphism)]
getGlobalImports lid l = fmap catMaybes $ mapR (getGlobalImport lid) l

getGlobalImport :: forall lid sublogics
        basic_spec sentence symb_items symb_map_items
         sign morphism symbol raw_symbol proof_tree .
        Logic lid sublogics
         basic_spec sentence symb_items symb_map_items
          sign morphism symbol raw_symbol proof_tree =>
               lid -> LEdge DGLinkLab -> Result (Maybe (Int, morphism))
getGlobalImport lid (_, _, llab) =
    let lt = dgl_type llab in
    -- check the type of the linklabel first
    if isDefEdge lt
    then
        if isLocalEdge lt
        then do
          -- local edges aren't supported...
          warning ()
             (unlines
              ["Local link with " ++ show (dgl_id llab)
               ++ " not supported.", 
               "The result of pathify may not be as expected."]) nullRange
          -- and will be skipped
          return Nothing
        else
            -- we have a global edge here
            case (dgl_morphism llab, dgl_id llab) of
              (GMorphism cid _ _ mor _, EdgeId n) ->
                  do
                    hmor <- coerceMorphism (targetLogic cid) lid
                            "getGlobalImport" mor
                    return $ Just (n, hmor)
    -- theorem links will be skipped
    else return Nothing
