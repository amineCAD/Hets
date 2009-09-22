{-# LANGUAGE CPP #-}
{- |
Module      :  $Id$
Copyright   :  (c) Uni Bremen 2003-2005
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  Christian.Maeder@dfki.de
Stability   :  provisional
Portability :  non-portable (imports Logic.Logic)

The Main module of the Heterogeneous Tool Set.
   It provides the main function to call (and not much more).

-}

-- for interactice purposes use Test.hs

module Main where

import System.Environment (getArgs)

import Driver.Options
import Driver.AnaLib
import Driver.WriteFn

import Static.DevGraph

#ifndef NOOWLLOGIC
import OWL.OWLAnalysis
#endif

#ifdef HXTFILTER
import OMDoc.OMDocInput
#endif

#ifdef UNI_PACKAGE
import GUI.ShowGraph
#endif

#ifdef PROGRAMATICA
import Haskell.Haskell2DG
#endif
import System.Exit (ExitCode(ExitSuccess), exitWith)

#ifdef SHELLAC
import CMDL.Interface
import PGIP.XMLparsing
#endif

import Maude.Maude2DG (anaMaudeFile)

main :: IO ()
main =
    getArgs >>= hetcatsOpts >>= \ opts ->
     let xFlag = xmlFlag opts
         iFiles = infiles opts in
#ifdef SHELLAC
     if connectP opts /= -1 || listen opts /= -1
       then
        cmdlListenOrConnect2Port opts >> return ()
       else
        if interactive opts
         then do
          if xFlag
           then
            cmdlRunXMLShell opts
           else
            cmdlRunShell opts iFiles
          return ()
         else
#endif
          do
          putIfVerbose opts 3 ("Options: " ++ show opts)
          mapM_ (processFile opts) iFiles

processFile :: HetcatsOpts -> FilePath -> IO ()
processFile opts file = do
    putIfVerbose opts 3 ("Processing input: " ++ file)
    res <- case guess file (intype opts) of
#ifdef PROGRAMATICA
      HaskellIn -> anaHaskellFile opts file
#endif
#ifndef NOOWLLOGIC
      OWLIn -> parseOWL file >>= structureAna file opts
#endif
#ifdef HXTFILTER
      OmdocIn -> mLibEnvFromOMDocFile opts file
#endif
      PrfIn -> anaLibReadPrfs opts file
#ifdef SHELLAC
      ProofCommand -> do
        putStrLn "Start processing a proof command file"
        cmdlProcessFile opts file
        return Nothing
#endif
      MaudeIn -> anaMaudeFile opts file
      _ -> anaLib opts file
    case res of
      Just (ln, nEnv) -> writeSpecFiles opts file nEnv ln $ lookupDGraph ln nEnv
      _ -> return ()
    case guiType opts of
      NoGui -> return ()
      UseGui ->
#ifdef UNI_PACKAGE
        showGraph file opts res >> exitWith ExitSuccess
#else
        fail $ "No graph display interface; \n"
          ++ "UNI_PACKAGE option has been "
          ++ "disabled during compilation of Hets"
#endif
