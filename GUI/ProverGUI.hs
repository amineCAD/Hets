{-# OPTIONS -cpp #-}
{- |
Module      :  $Header$
Description :  cpp choice between "GUI.ProofManagement" and "GUI.GtkProverGUI"
Copyright   :  (c) C. Maeder, Uni Bremen 2002-2005
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  Christian.Maeder@dfki.de
Stability   :  provisional
Portability :  non-portable (cpp)

cpp choice between "GUI.ProofManagement" and "GUI.GtkProverGUI"
-}

module GUI.ProverGUI
  ( proverGUI ) where

import Logic.Comorphism
import Logic.Logic
import Static.GTheory
import Common.Result as Result
import Proofs.AbstractState
import qualified Comorphisms.KnownProvers as KnownProvers
import Control.Concurrent

#ifdef GTKGLADE
-- import GUI.GtkProverGUI
#endif

import GUI.ProofManagement

proverGUI ::
  (Logic lid sublogics1
             basic_spec1
             sentence
             symb_items1
             symb_map_items1
             sign1
             morphism1
             symbol1
             raw_symbol1
             proof_tree1) =>
     lid
  -> ProofActions lid sentence -- ^ record of possible GUI actions
  -> String -- ^ theory name
  -> String -- ^ warning information
  -> G_theory -- ^ theory
  -> KnownProvers.KnownProversMap -- ^ map of known provers
  -> [(G_prover,AnyComorphism)] -- ^ list of suitable comorphisms to provers
                                -- for sublogic of G_theory
  -> IO (Result.Result G_theory)
proverGUI lid prGuiAcs thName warningTxt th knownProvers comorphList = do
  guiMVar <- newMVar Nothing
  proofManagementGUI lid prGuiAcs thName warningTxt th knownProvers comorphList
                     guiMVar

