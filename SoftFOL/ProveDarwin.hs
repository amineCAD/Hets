{- |
Module      :  $Header$
Description :  Interface to the TPTP theorem prover via Darwin.
Copyright   :  (c) Heng Jiang, Uni Bremen 2004-2007
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt
Maintainer  :  jiang@informatik.uni-bremen.de
Stability   :  provisional
Portability :  needs POSIX

Interface for the Darwin service, uses GUI.GenericATP.
See <http://spass.mpi-sb.mpg.de/> for details on SPASS, and
<http://combination.cs.uiowa.edu/Darwin/> for Darwin.
-}

module SoftFOL.ProveDarwin (darwinProver,darwinGUI,darwinCMDLautomatic,
                           darwinCMDLautomaticBatch,
                           darwinConsChecker) where

import Logic.Prover

import SoftFOL.Sign
import SoftFOL.Translate
import SoftFOL.ProverState
import SoftFOL.ProveHelp()


import qualified Common.AS_Annotation as AS_Anno
import qualified Common.Result as Result

import Data.List (isPrefixOf)
import Data.Time (timeToTimeOfDay)
import Data.Time.Clock (UTCTime(..), secondsToDiffTime, getCurrentTime)

import qualified Control.Concurrent as Concurrent

import HTk
import System
import System.IO
import System.Process
import GUI.GenericATP
import GUI.GenericATPState
import Proofs.BatchProcessing
import Common.DefaultMorphism
import GUI.HTkUtils

-- * Prover implementation

{- |
  The Prover implementation. First runs the batch prover (with graphical feedback), then starts the GUI prover.
-}
darwinProver :: Prover Sign Sentence () ATP_ProofTree
darwinProver = (mkProverTemplate "Darwin" () darwinGUI)
    { proveCMDLautomatic = Just darwinCMDLautomatic
    , proveCMDLautomaticBatch = Just darwinCMDLautomaticBatch }

darwinConsChecker :: ConsChecker Sign Sentence () (DefaultMorphism Sign) ATP_ProofTree
darwinConsChecker = mkProverTemplate "darwin" () consCheck
{- |
  Record for prover specific functions. This is used by both GUI and command
  line interface.
-}
atpFun :: String -- ^ theory name
       -> ATPFunctions Sign Sentence ATP_ProofTree SoftFOLProverState
atpFun thName = ATPFunctions
    { initialProverState = spassProverState,
      atpTransSenName = transSenName,
      atpInsertSentence = insertSentenceGen,
      goalOutput = showTPTPProblem thName,
      proverHelpText = "no help for darwin available",
      batchTimeEnv = "HETS_SPASS_BATCH_TIME_LIMIT",
      fileExtensions = FileExtensions{problemOutput = ".tptp",
                                      proverOutput = ".spass",
                                      theoryConfiguration = ".spcf"},
      runProver = runDarwin,
      createProverOptions = extraOpts}

-- ** GUI

{- |
  Invokes the generic prover GUI. SPASS specific functions are omitted by
  data type ATPFunctions.
-}
darwinGUI :: String -- ^ theory name
           -> Theory Sign Sentence ATP_ProofTree
           -- ^ theory consisting of a SoftFOL.Sign.Sign
           --   and a list of Named SoftFOL.Sign.Sentence
           -> IO([Proof_status ATP_ProofTree]) -- ^ proof status for each goal
darwinGUI thName th =
    genericATPgui (atpFun thName) True (prover_name darwinProver) thName th $
                  ATP_ProofTree ""

-- ** command line functions

{- |
  Implementation of 'Logic.Prover.proveCMDLautomatic' which provides an
  automatic command line interface for a single goal.
  Darwin specific functions are omitted by data type ATPFunctions.
-}
darwinCMDLautomatic ::
           String -- ^ theory name
        -> Tactic_script -- ^ default tactic script
        -> Theory Sign Sentence ATP_ProofTree
           -- ^ theory consisting of a signature and a list of Named sentence
        -> IO (Result.Result ([Proof_status ATP_ProofTree]))
           -- ^ Proof status for goals and lemmas
darwinCMDLautomatic thName defTS th =
    genericCMDLautomatic (atpFun thName) (prover_name darwinProver) thName
        (parseTactic_script batchTimeLimit [] defTS) th (ATP_ProofTree "")

{- |
  Implementation of 'Logic.Prover.proveCMDLautomaticBatch' which provides an
  automatic command line interface to the Darwin prover via MathServe.
  Darwin specific functions are omitted by data type ATPFunctions.
-}
darwinCMDLautomaticBatch ::
           Bool -- ^ True means include proved theorems
        -> Bool -- ^ True means save problem file
        -> Concurrent.MVar (Result.Result [Proof_status ATP_ProofTree])
           -- ^ used to store the result of the batch run
        -> String -- ^ theory name
        -> Tactic_script -- ^ default tactic script
        -> Theory Sign Sentence ATP_ProofTree -- ^ theory consisting of a
           --   'SoftFOL.Sign.Sign' and a list of Named 'SoftFOL.Sign.Sentence'
        -> IO (Concurrent.ThreadId,Concurrent.MVar ())
           -- ^ fst: identifier of the batch thread for killing it
           --   snd: MVar to wait for the end of the thread
darwinCMDLautomaticBatch inclProvedThs saveProblem_batch resultMVar
                        thName defTS th =
    genericCMDLautomaticBatch (atpFun thName) inclProvedThs saveProblem_batch
        resultMVar (prover_name darwinProver) thName
        (parseTactic_script batchTimeLimit [] defTS) th (ATP_ProofTree "")

-- * Main prover functions
{- |
  Runs the Darwin service.
-}

spamOutput :: Proof_status ATP_ProofTree -> IO ()
spamOutput ps =
    let
        dName = goalName ps
        dStat = goalStatus ps
        dTree = proofTree ps
    in
      case dStat of
        Open -> createTextSaveDisplay "Darwin prover" ("./"++ dName ++".darwin.log")
                (
                 "I was not able to find a model for the goal " ++
                 dName ++". :( \n" ++
                 show dTree
                )
        Disproved -> createTextSaveDisplay "Darwin prover" ("./"++ dName ++".darwin.log")
                (
                 "Your theory " ++
                 dName ++" has no model. :( \n" ++
                 show dTree
                )
        Proved _ -> createTextSaveDisplay "Darwin prover" ("./"++ dName ++".darwin.log")
                (
                 "I found a model for the theory " ++
                 dName ++". :) \n" ++
                 show dTree
                )


consCheck :: String -> TheoryMorphism Sign Sentence (DefaultMorphism Sign) ATP_ProofTree
          -> IO([Proof_status ATP_ProofTree])
consCheck thName tm = case t_target tm of
                        Theory sig nSens ->
                            let
                                saveTPTP = False
                                timeLimitI = 800
                                tac      = Tactic_script $ show $ ATPTactic_script
                                           {ts_timeLimit = timeLimitI,
                                            ts_extraOpts = [extraOptions]
                                           }
                                proverStateI = spassProverState sig
                                              (toNamedList nSens)
                                problem     = showTPTPProblemM thName proverStateI []
                                simpleOptions = ""
                                extraOptions  = "-pc true -pmtptp true -fd true -to " ++ (show timeLimitI)
                                saveFileName  = (reverse $ fst $ span (/='/') $ reverse thName)
                                tmpFileName   = (reverse $ fst $ span (/='/') $ reverse thName)
                                runDarwinRealM :: IO([Proof_status ATP_ProofTree])
                                runDarwinRealM = do
                                         probl <- problem
                                         hasProgramm <- system ("which darwin > /dev/null 2> /dev/null")
                                         case hasProgramm of
                                           ExitFailure _ -> do
                                                            createInfoWindow "Darwin prover" "Darwin not found"
                                                            return [Proof_status
                                                                    {
                                                                      goalName = thName
                                                                    , goalStatus = Open
                                                                    , usedAxioms = getAxioms
                                                                    , proverName = (prover_name darwinProver)
                                                                    , proofTree  = ATP_ProofTree "Darwin not found"
                                                                    , usedTime = timeToTimeOfDay $
                                                                                 secondsToDiffTime 0
                                                                    ,tacticScript  = tac
                                                                    }]
                                           ExitSuccess -> do
                                                   when saveTPTP
                                                            (writeFile (saveFileName ++".tptp") probl)
                                                   t <- getCurrentTime
                                                   let timeTmpFile = "/tmp/" ++ tmpFileName ++ (show $ utctDay t) ++
                                                                     "-" ++ (show $ utctDayTime t) ++ ".tptp"
                                                   writeFile timeTmpFile probl
                                                   let command = "darwin " ++ extraOptions ++ " " ++ timeTmpFile
                                                   (_, outh, errh, proch) <- runInteractiveCommand command
                                                   (exCode, output, tUsed) <- parseDarwinOut outh errh proch
                                                   let outState = [proof_statM exCode simpleOptions output tUsed]
                                                   spamOutput (head outState)
                                                   return $ outState

                                proof_statM :: ExitCode -> String ->  [String] -> Int -> Proof_status ATP_ProofTree
                                proof_statM exitCode _ out tUsed =
                                    case exitCode of
                                      ExitSuccess ->
                                          Proof_status
                                          {
                                            goalName = thName
                                          , goalStatus = Proved (Just True)
                                          , usedAxioms = getAxioms
                                          , proverName = (prover_name darwinProver)
                                          , proofTree =   ATP_ProofTree (unlines out)
                                          ,usedTime = timeToTimeOfDay $
                                            secondsToDiffTime $ toInteger tUsed
                                          ,tacticScript  = tac
                                          }
                                      ExitFailure 2 ->
                                          Proof_status
                                          {
                                            goalName = thName
                                          , goalStatus = Open
                                          , usedAxioms = getAxioms
                                          , proverName = (prover_name darwinProver)
                                          , proofTree  = ATP_ProofTree "Internal error :("
                                          ,usedTime = timeToTimeOfDay $
                                            secondsToDiffTime 0
                                          ,tacticScript  = tac
                                          }
                                      ExitFailure 112 ->
                                          Proof_status
                                          {
                                            goalName = thName
                                          , goalStatus = Open
                                          , usedAxioms = getAxioms
                                          , proverName = (prover_name darwinProver)
                                          , proofTree =   ATP_ProofTree (unlines out)
                                          ,usedTime = timeToTimeOfDay $
                                            secondsToDiffTime $ toInteger tUsed
                                          ,tacticScript  = tac
                                          }
                                      ExitFailure 105 ->
                                          Proof_status
                                          {
                                            goalName = thName
                                          , goalStatus = Open
                                          , usedAxioms = getAxioms
                                          , proverName = (prover_name darwinProver)
                                          , proofTree =   ATP_ProofTree (unlines out)
                                          ,usedTime = timeToTimeOfDay $
                                            secondsToDiffTime $ toInteger tUsed
                                          ,tacticScript  = tac
                                          }
                                      ExitFailure _ ->
                                          Proof_status
                                          {
                                            goalName = thName
                                          , goalStatus = Disproved
                                          , usedAxioms = getAxioms
                                          , proverName = (prover_name darwinProver)
                                          , proofTree =   ATP_ProofTree (unlines out)
                                          ,usedTime = timeToTimeOfDay $
                                            secondsToDiffTime $ toInteger tUsed
                                          ,tacticScript  = tac
                                          }

                                getAxioms = let fl = formulaLists $ initialLogicalPart proverStateI
                                                fs = foldl (++) [] (map formulae $ filter isAxiomFormula fl)
                                            in map AS_Anno.senAttr fs
                            in
                              runDarwinRealM


runDarwin :: SoftFOLProverState
           -- ^ logical part containing the input Sign and axioms and possibly
           --   goals that have been proved earlier as additional axioms
           -> GenericConfig ATP_ProofTree -- ^ configuration to use
           -> Bool -- ^ True means save TPTP file
           -> String -- ^ name of the theory in the DevGraph
           -> AS_Anno.Named SPTerm -- ^ goal to prove
           -> IO (ATPRetval, GenericConfig ATP_ProofTree)
           -- ^ (retval, configuration with proof status and complete output)
runDarwin sps cfg saveTPTP thName nGoal = do
  -- putStrLn ("running Darwin...")
  runDarwinReal

  where
    simpleOptions = extraOpts cfg
    extraOptions  = maybe "-pc false"
        ( \ tl -> "-pc false" ++ " -to " ++ show tl) $ timeLimit cfg
    saveFileName  = thName++'_':AS_Anno.senAttr nGoal
    tmpFileName   = (reverse $ fst $ span (/='/') $ reverse thName) ++
                       '_':AS_Anno.senAttr nGoal
    -- tLimit = maybe (guiDefaultTimeLimit) id $ timeLimit cfg

    runDarwinReal = do
      hasProgramm <- system ("which darwin > /dev/null 2> /dev/null")
      case hasProgramm of
        ExitFailure _ -> return
            (ATPError "Could not start Darwin. Is Darwin in your $PATH?",
                  emptyConfig (prover_name darwinProver)
                              (AS_Anno.senAttr nGoal) $ ATP_ProofTree "")
        ExitSuccess -> do
          prob <- showTPTPProblem thName sps nGoal $
                      simpleOptions ++ ["Requested prover: Darwin"]
          when saveTPTP
            (writeFile (saveFileName ++".tptp") prob)
          t <- getCurrentTime
          let timeTmpFile = "/tmp/" ++ tmpFileName ++ (show $ utctDay t) ++
                               "-" ++ (show $ utctDayTime t) ++ ".tptp"
          writeFile timeTmpFile prob
          let command = "darwin " ++ extraOptions ++ " " ++ timeTmpFile
          -- putStrLn command
          (_, outh, errh, proch) <- runInteractiveCommand command
          (exCode, output, tUsed) <- parseDarwinOut outh errh proch
          let (err, retval) = proof_stat exCode simpleOptions output tUsed
          return (err,
                  cfg{proof_status = retval,
                      resultOutput = output,
                      timeUsed     = timeToTimeOfDay $
                                 secondsToDiffTime $ toInteger tUsed})

    proof_stat exitCode options out tUsed =
            case exitCode of
              ExitSuccess -> (ATPSuccess, proved_status options tUsed)
              ExitFailure 2 -> (ATPError (unlines ("Internal error.":out)),
                                defaultProof_status options)
              ExitFailure 112 ->
                       (ATPTLimitExceeded, defaultProof_status options)
              ExitFailure 105 ->
                       (ATPBatchStopped, defaultProof_status options)
              ExitFailure _ ->
                  (ATPSuccess, disProved_status options)

    defaultProof_status opts =
            (openProof_status
            (AS_Anno.senAttr nGoal) (prover_name darwinProver) $
                                    ATP_ProofTree "")
                       {tacticScript = Tactic_script $ show $ ATPTactic_script
                        {ts_timeLimit = configTimeLimit cfg,
                         ts_extraOpts = opts} }

    disProved_status opts = (defaultProof_status opts)
                               {goalStatus = Disproved}

    proved_status opts ut =
        Proof_status{
               goalName = AS_Anno.senAttr nGoal
              ,goalStatus = Proved (Just True)
              ,usedAxioms = getAxioms -- []
              ,proverName = (prover_name darwinProver)
              ,proofTree =   ATP_ProofTree ""
              ,usedTime = timeToTimeOfDay $
                                 secondsToDiffTime $ toInteger ut
              ,tacticScript  = Tactic_script $ show $ ATPTactic_script
                               {ts_timeLimit = configTimeLimit cfg,
                                ts_extraOpts = opts}
                    }

    getAxioms = let fl = formulaLists $ initialLogicalPart sps
                    fs = foldl (++) [] (map formulae $ filter isAxiomFormula fl)
                in map AS_Anno.senAttr fs

isAxiomFormula :: SPFormulaList -> Bool
isAxiomFormula fl =
    case originType fl of
      SPOriginAxioms -> True
      _              -> False

parseDarwinOut :: Handle        -- ^ handel of stdout
               -> Handle        -- ^ handel of stderr
               -> ProcessHandle -- ^ handel of process
               -> IO (ExitCode, [String], Int)
                       -- ^ (exit code, complete output, used time)

parseDarwinOut outh _ proc = do
    --darwin does not write to stderr here, so ignore output
    --err <- hGetLine errh
    --if null err then 
  readLineAndParse (ExitFailure 1, [], -1) False
  where
   readLineAndParse (exCode, output, to) stateFound = do
    procState <- isProcessRun
    case procState of
     ExitSuccess -> do
      iseof <- hIsEOF outh
      if iseof then
          do -- ec <- isProcessRun proc
             waitForProcess proc
             return (exCode, output, to)
        else do
          line <-hGetLine outh
          -- putStrLn ("line:  " ++ line)
          let (okey, ovalue) = span (/=':') line
          if "Try darwin -h for further information" `isPrefixOf` line
             -- error by running darwin.
            then do waitForProcess proc
                    return (ExitFailure 2, (output ++ [line]), to)
            else if okey == "SZS status"    -- get SZS state
                   then readLineAndParse (checkSZSState (tail $ tail ovalue),
                                          (output ++ [line]), to) True
                   else if "CPU Time" `isPrefixOf` okey  -- get cup time
                           then readLineAndParse (exCode, (output ++ [line]),
                           ((read $ fst $ span (/='.') $ tail ovalue)::Int))
                                                                  stateFound
                           else if null ovalue && "SZS status" `isPrefixOf` line && not stateFound  -- an other SZS state description......
                                 then do let state' = words line !! 2
                                         readLineAndParse (checkSZSState state', (output ++ [line]), to) True
                                 else readLineAndParse (exCode, (output ++ [line]), to) stateFound

     failure -> do waitForProcess proc
                   return (failure, output, to)

   checkSZSState szsState =
        case szsState of
          "Unsolved"         -> ExitFailure 101
          "Open"             -> ExitFailure 102
          "Unknown"          -> ExitFailure 103
          "Assumed"          -> ExitFailure 104
          "Stopped"          -> ExitFailure 105
          "Error"            -> ExitFailure 106
          "InputError"       -> ExitFailure 107
          "OSError"          -> ExitFailure 108
          "Forced"           -> ExitFailure 109
          "User"             -> ExitFailure 110
          "ResourceOut"      -> ExitFailure 111
          "Timeout"          -> ExitFailure 112
          "MemoryOut"        -> ExitFailure 113
          "Gaveup"           -> ExitFailure 114
          "Incomplete"       -> ExitFailure 115
          "Inappropriate"    -> ExitFailure 116
          "NotTested"        -> ExitFailure 117
          "NotTestedYet"     -> ExitFailure 118
          "CounterSatisfiable"  -> ExitFailure 119
          "CounterTheorem"   -> ExitFailure 120
          "CounterEquivalent"  -> ExitFailure 121
          "WeakerCounterTheorem"  -> ExitFailure 122
          "UnsatisfiableConclusion"  -> ExitFailure 123
          "EquivalentCounterTheorem"  -> ExitFailure 124
          "Unsatisfiable"    -> ExitFailure 125
          "SatisfiableCounterConclusionContradictoryAxioms" -> ExitFailure 126
          "UnsatisfiableConclusionContradictoryAxioms" -> ExitFailure 127
          "NoConsequence"    -> ExitFailure 128
          "CounterSatisfiabilityPreserving"   -> ExitFailure 129
          "CounterSatisfiabilityPartialMapping"  -> ExitFailure 130
          "CounterSatisfiabilityMapping"  -> ExitFailure 131
          "CounterSatisfiabilityBijection"  -> ExitFailure 132
          _                  -> ExitSuccess

    -- check if darwin running
   isProcessRun = do
      exitcode <- getProcessExitCode proc
      case exitcode of
        Nothing -> return ExitSuccess
        Just (ExitFailure i) -> return (ExitFailure i)
        Just ExitSuccess     -> return ExitSuccess
