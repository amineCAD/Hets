{- |
Module      :  $Header$
Description :  generate DriFT directives
Copyright   :  (c) Felix Reckers, C. Maeder, Uni Bremen 2002-2006
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  maeder@tzi.de
Stability   :  provisional
Portability :  portable

generate files for DriFT to derive instances (i.e. for ATerms)
-}

module Main (main) where

import System.Console.GetOpt
import System.Environment
import ParseFile
import Data.List
import Data.Char

data Flag = Rule String | Exclude String | Import String | Output String
            deriving Show

{- previous header files should be replaced by proper imports and
   possibly excluding some data types.
   There may be several -r, -x and -i flags.
-}

options :: [OptDescr Flag]
options = [
           Option ['r'] ["rule"] (ReqArg Rule "Rule")
                   "the rule for the actual DrIFT derivation",
           Option ['x'] ["exclude"] (ReqArg Exclude "Data")
            "exclude the specified data-types",
           Option ['i'] ["import"] (ReqArg Import "Module")
            "additionally import the given file(s)",
           Option ['o'] ["output-file"] (ReqArg Output "File")
            "specifies the output-directory"
          ]

main :: IO ()
main = do args <- getArgs
          case (getOpt RequireOrder options args) of
            (flags, files, []) -> if null files
                then fail "missing input file(s)" else genRules flags files
            (_, _, errs) -> fail $ concat errs ++ usageInfo usage options
       where usage = "Usage: genRules [OPTION...] file [file ...]"

-- | only place imports and data directives into the output module
genRules :: [Flag] -> [FilePath] -> IO ()
genRules flags files =
    do ids <- mapM readParseFile files
       let q@(rules, excs, is, outf) = anaFlags flags
           (datas, imports) = (( \ (x,y) -> (concat x,concat y)) . unzip) ids
           ds = datas \\ excs
           rule =  concat $ intersperse ", " rules
           fileHead = "{-# OPTIONS -fno-warn-unused-imports #-}" ++
             "\n{- |\nModule      :  " ++ outf ++
             "\nDescription :  generated " ++ rule ++ " instances" ++
             "\nCopyright   :  (c) Uni Bremen 2005" ++
             "\nLicense     :  similar to LGPL, see HetCATS/LICENSE.txt" ++
             "\n\nMaintainer  :  maeder@tzi.de" ++
             "\nStability   :  provisional" ++
             "\nPortability :  portable\n" ++
             "\nAutomatic derivation of instances via DrIFT-rule " ++
                   rule ++
             "\n  for the type(s):" ++
                   concatMap ( \ d -> " '" ++ d ++ "'") ds ++
             "\n-}\n" ++ "{-\n  Generated by 'genRules' " ++
             "(automatic rule generation for DrIFT). Don't touch!!" ++
             "\n  dependency files: " ++ unwords files ++ "\n-}"
       checkFlags q
       if null ds then fail "no data types left" else
           writeFile outf $
                  fileHead ++ "\n\nmodule " ++ toModule outf
                  ++ " where\n"
                  ++ concatMap ( \ i -> "\nimport " ++ i )
                                            (imports ++ is)
                  ++ "\n"
                  ++ concatMap ( \ r -> "\n" ++
                         concatMap ( \ d -> "{-! for " ++ d
                                 ++ " derive : " ++ r ++ " !-}\n")
                                 ds) rules

readParseFile :: FilePath -> IO ([String],[Import])
readParseFile fp =
    do inp <- readFile fp
       case parseInputFile fp inp of
         Left err -> fail $ "parse error at " ++ err
         Right x  -> return x

anaFlags :: [Flag] -> ([String], [String], [Import], FilePath)
anaFlags [] = ([], [], [], "")
anaFlags (x : xs) = let
    (rs, ds, is, o) = anaFlags xs in case x of
    Rule r -> (r : rs, ds, is, o)
    Exclude d -> (rs, d : ds, is, o)
    Import i -> (rs, ds, i : is, o)
    Output outFile ->  (rs, ds, is, outFile)

checkFlags :: ([String], [String], [Import], FilePath) -> IO ()
checkFlags (rs, ds, is, o) =
    if null rs then fail "no rule given."
    else let frs = filter wrong rs in if not (null frs)
         then fail $ "wrong rule to apply: " ++ head frs
    else if wrong o then fail $ "no module output file given. " ++ o
    else let fds = filter wrong ds in if not (null fds)
         then fail $ "wrong data type to exclude: " ++ head fds
    else let fis = filter wrong is in if not (null fis)
         then fail $ "wrong module to import: " ++ head fis
    else return ()
    where wrong s = null s || not (isUpper $ head s)

toModule :: FilePath -> String
toModule fp = map ( \ c -> if c == '/' then '.' else c)
                           $ takeWhile (/= '.') fp
