{- |
   > HetCATS/hets.hs
   $Id$
   Author: Klaus L�ttich
   Year:   2003

   The Main module of the hetcats system. It provides the main function
   to call.

-}
module Main where

import Common.Utils

import Options
import System.Environment
import Static.AnalysisLibrary
import Logic.LogicGraph
-- import GUI.ConvertDevToAbstractGraph -- requires uni-package

import ReadFn
import WriteFn
-- import ProcessFn
import Syntax.Print_HetCASL

import Debug.Trace
import Common.Result
import Static.DevGraph

main :: IO ()
main = 
    do opt <- getArgs >>= hetcatsOpts
       if (verbose opt >= 3) then putStr "Options: " >> print opt
          else return ()
       sequence_ $ map (processFile opt) (infiles opt)

processFile :: HetcatsOpts -> FilePath -> IO ()
processFile opt file = 
    do ld <- read_LIB_DEFN opt file
       -- (env,ld') <- analyse_LIB_DEFN opt
       (ld',env) <- if (analysis opt)
                       then do Result diags res <- 
                                ioresToIO 
                                  (ana_LIB_DEFN logicGraph defaultLogic emptyLibEnv opt ld)
                               -- sequence (map (putStrLn . show) diags)
                               return (ld, res)
                       else return (ld, Nothing)
       let odir = if (null (outdir opt)) then (dirname file)
                     else (outdir opt)
       trace ("selected OutDir: " ++ odir) (return ())
       write_LIB_DEFN (opt { outdir = odir }) ld'
       -- write_GLOBAL_ENV env

