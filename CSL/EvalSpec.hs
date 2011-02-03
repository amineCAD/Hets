{- |
Module      :  $Header$
Description :  EvalSpec program
Copyright   :  (c) Ewaryst Schulz, DFKI Bremen 2010
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  ewaryst.schulz@dfki.de
Stability   :  experimental
Portability :  non-portable (via imports)

Program for evaluating EnCL specifications
-}


import System.Environment
import System.Console.GetOpt

import qualified Interfaces.Process as PC
import CSL.InteractiveTests
import Common.Utils

import Data.Bits
import Data.Maybe
import Data.List



main :: IO ()
main = do
  args <- getArgs
  case processArgs args of
    Left msg -> putStrLn $ "Evaluation: " ++ msg ++ "\n\n" ++ esUsage
    Right st -> runProg st >>= putStrLn

runProg :: ProgSettings -> IO String
runProg st = evalWithVerification (timeout st) (verbosity st) (lib st) (spec st) >> return ""

------------------------- Input Arguments -------------------------

processArgs :: [String] -> Either String ProgSettings
processArgs args =
    let (flags, noopts, unrecopts, errs) = getOpt' (ReturnInOrder PFLib) options args
        msgl = checkFlags flags
        f str (l, s) = if null l then str else str ++ "\n" ++ s ++ unlines l
        msg = foldl f ""
              [ (noopts, "non-handled extra arguments encountered ")
              , (unrecopts, "unrecognized flags encountered ")
              , (errs, "")
              , (msgl, "")
              ]
    in if null msg then Right $ getSettings flags else Left msg

esHeader :: String
esHeader = unlines
           [ "Usage: evalspec [OPTION...] [file]"
                  , ""
                  , "evalspec /tmp/f.het -sFlangeComplete"
                  , ""
                  ]

esUsage :: String
esUsage = usageInfo esHeader options

{- | 'options' describes all available options and is used to generate usage
information -}
options :: [OptDescr ProgFlag]
 -- Option [Char] [String] (ArgDescr a) String
options = map f $
          [ ( "lib", "Path to the hets file", ReqArg PFLib "FILE")
          , ( "spec"
            , "Name of specification importing both, the pattern and the design specification"
            , ReqArg PFSpec "SPECNAME")
          , ( "timeout"
            , "Timeout for communication with external CAS system in deziseconds (tenth of a second)"
            , ReqArg (PFTimeout . fromRational
                      . fromMaybe (error "Could not parse timeout")
                      . (readMaybe :: String -> Maybe Rational)
                      . (++ "%10")) "1-1000")
          , ( "verbosity"
            , "A value from 0=quiet to 4=print out all information during processing"
            , OptArg (PFVerbosity . read . fromMaybe "4") "0-4")
          , ( "quiet", "Equal to -v0", NoArg PFQuiet)
          ] where
    f (fs, descr, arg) = Option [head fs] [fs] arg descr

checkFlags :: [ProgFlag] -> [String]
checkFlags = g . mapAccumL f (0::Int) where
    f i (PFLib _) = (setBit i 0, ())
    f i (PFSpec _) = (setBit i 1, ())
    f i _ = (i, ())
    g (i, _) = mapMaybe (h i) [ (0, "lib")
                              , (1, "spec") ]
    h i (j, s)
      | testBit i j = Nothing
      | otherwise = Just $ s ++ " argument is missing"

data ProgSettings =
    ProgSettings
    { lib :: String
    , spec :: String
    , timeout :: PC.DTime
    , verbosity :: Int }


defaultSettings :: ProgSettings
defaultSettings = ProgSettings
                  { lib = error "uninitialized settings"
                  , spec = error "uninitialized settings"
                  , timeout = 1
                  , verbosity = 4 }

data ProgFlag =
    PFLib String
        | PFSpec String
        | PFTimeout PC.DTime
        | PFVerbosity Int
        | PFQuiet

makeSettings :: ProgSettings -> ProgFlag -> ProgSettings
makeSettings settings flg =
    case flg of
      PFLib s -> settings { lib = s }
      PFSpec s -> settings { spec = s }
      PFVerbosity i -> settings { verbosity = i }
      PFQuiet -> settings { verbosity = 0 }
      PFTimeout t -> settings { timeout = t }
      
getSettings :: [ProgFlag] -> ProgSettings
getSettings = foldl makeSettings defaultSettings
