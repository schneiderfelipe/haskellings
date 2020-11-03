import Control.Concurrent
import Data.List
import Data.Time
import System.Directory
import System.Exit
import System.IO
import Test.Hspec
import Test.HUnit

import Config
import ExerciseList
import Utils
import Watcher

main :: IO ()
main = do
  loadResult <- loadProjectRootAndGhc
  case loadResult of
    Left _ -> error "Unable to find project root or GHC 8.8.4!"
    Right paths -> do
      createDirectoryIfMissing True (fst paths ++ "/tests/test_gen")
      hspec $ describe "Basic Compile Tests" $ do
        compileTests1 paths
        compileTests2 paths
        compileAndRunTestFail1 paths
        compileAndRunTestFail2 paths
        compileAndRunTestPass paths
        watchTests paths

compileBeforeHook :: (FilePath, FilePath) -> ExerciseInfo -> FilePath -> IO (String, RunResult)
compileBeforeHook (projectRoot, ghcPath) exInfo outFile = do
  let fullFp = projectRoot ++ "/tests/test_gen/" ++ outFile
  outHandle <- openFile fullFp WriteMode
  let conf = ProgramConfig projectRoot ghcPath "/tests/exercises/" stdin outHandle stderr
  resultExit <- compileExercise conf exInfo
  hClose outHandle
  programOutput <- readFile fullFp
  return (programOutput, resultExit)

isFailureOutput :: String -> Expectation
isFailureOutput output = do
  let outputLines = lines output
  length outputLines `shouldSatisfy` (> 1)
  head outputLines `shouldSatisfy` (isPrefixOf "Couldn't compile :")

isRunFailureOutput :: String -> Expectation
isRunFailureOutput output = do
  let outputLines = lines output
  length outputLines `shouldSatisfy` (> 1)
  head outputLines `shouldSatisfy` (isPrefixOf "Successfully compiled :")
  outputLines !! 1 `shouldSatisfy` (isPrefixOf "Tests failed on exercise :")

isSuccessOutput :: String -> Expectation
isSuccessOutput output = output `shouldSatisfy` (isPrefixOf "Successfully compiled :")

isSuccessRunOutput :: String -> Expectation
isSuccessRunOutput output = do
  let outputLines = lines output
  length outputLines `shouldBe` 2
  head outputLines `shouldSatisfy` (isPrefixOf "Successfully compiled :")
  outputLines !! 1 `shouldSatisfy` (isPrefixOf "Successfully ran :")

compileTests1 :: (FilePath, FilePath) -> Spec
compileTests1 paths = before (compileBeforeHook paths exInfo "types1_bad.output") $
  describe "When running 'compileExercise' with non-compiling file" $
    it "Should indicate failure to compile and return a failing exit code" $ \(output, exit) -> do
      exit `shouldBe` CompileError
      isFailureOutput output
  where
    exInfo = ExerciseInfo "Types1Bad" "types" "Types1Bad.hs" False ""

compileTests2 :: (FilePath, FilePath) -> Spec
compileTests2 paths = before (compileBeforeHook paths exInfo "types1_good.output") $
  describe "When running 'compileExercise' with compiling file" $
    it "Should indicate successful compilation and return a success exit code" $ \(output, exit) -> do
      exit `shouldBe` RunSuccess
      isSuccessOutput output
  where
    exInfo = ExerciseInfo "Types1Good" "types" "Types1Good.hs" False ""

compileAndRunTestFail1 :: (FilePath, FilePath) -> Spec
compileAndRunTestFail1 paths = before (compileBeforeHook paths exInfo "recursion1_bad1.output") $
  describe "When running 'compileExercise' with non-compiling and runnable file" $
    it "Should indicate failure to compile and return a failing exit code" $ \(output, exit) -> do
      exit `shouldBe` CompileError
      isFailureOutput output
  where
    exInfo = ExerciseInfo "Recursion1Bad1" "recursion" "Recursion1Bad1.hs" True ""

compileAndRunTestFail2 :: (FilePath, FilePath) -> Spec
compileAndRunTestFail2 paths = before (compileBeforeHook paths exInfo "recursion1_bad2.output") $
  describe "When running 'compileExercise' with compiling but incorrect file" $
    it "Should indicate test failures and return a failing exit code" $ \(output, exit) -> do
      isRunFailureOutput output
      exit `shouldBe` TestFailed
  where
    exInfo = ExerciseInfo "Recursion1Bad2" "recursion" "Recursion1Bad2.hs" True ""

compileAndRunTestPass :: (FilePath, FilePath) -> Spec
compileAndRunTestPass paths = before (compileBeforeHook paths exInfo "recursion1_good.output") $
  describe "When running 'compileExercise' with compiling and runnable file" $
    it "Should indicate successful compilation and return a success exit code" $ \(output, exit) -> do
      exit `shouldBe` RunSuccess
      isSuccessRunOutput output
  where
    exInfo = ExerciseInfo "Recursion1Good" "recursion" "Recursion1Good.hs" True ""






watchTestExercises :: [ExerciseInfo]
watchTestExercises =
  [ ExerciseInfo "Types1" "watcher_types" "Types1.hs" False "What type should you fill in for the variable?"
  , ExerciseInfo "Types2" "watcher_types" "Types2.hs" False "What type can you fill in for the tuple?"
  ]

watchTests :: (FilePath, FilePath) -> Spec
watchTests paths = before (beforeWatchHook paths "watcher_tests_.out") $
  describe "When running watcher" $
    it "Should step the through the watch process in stages" $ \outputs -> do
      assertSequence expectedSequence (lines outputs)
  where
    expectedSequence =
      [ "Couldn't compile : Types1.hs"
      , "What type should you fill in for the variable?"
      , "Successfully compiled : Types1.hs"
      , "This exercise succeeds! Remove 'I AM NOT DONE' to proceed!"
      , "Successfully compiled : Types1.hs"
      , "Couldn't compile : Types2.hs"
      , "Successfully compiled : Types2.hs"
      , "This exercise succeeds! Remove 'I AM NOT DONE' to proceed!"
      , "Successfully compiled : Types2.hs"
      , "Congratulations, you've completed all the exercises!"
      ]

assertSequence :: [String] -> [String] -> Expectation
assertSequence [] _ = return ()
assertSequence remaining [] = assertFailure $
  "Did not find all expected messages. Remaining: " ++ show remaining
assertSequence all@(expectedString : restExpected) (fileLine : restFile) =
  if expectedString == fileLine
    then assertSequence restExpected restFile
    else assertSequence all restFile

makeModifications :: [(FilePath, FilePath)] -> IO ()
makeModifications [] = return ()
makeModifications ((src, dst) : rest) = do
  threadDelay 1000000
  copyFile src dst
  getCurrentTime >>= setModificationTime dst
  threadDelay 1000000
  makeModifications rest

beforeWatchHook :: (FilePath, FilePath) -> FilePath -> IO String
beforeWatchHook (projectRoot, ghcPath) outFile = do
  -- Copy Original Files
  copyFile (addFullDirectory "Types1Orig.hs") fullDest1
  copyFile (addFullDirectory "Types2Orig.hs") fullDest2
  -- Build Configuration
  let fullFp = projectRoot ++ "/tests/test_gen/" ++ outFile
  let fullIn = projectRoot ++ "/tests/watcher_tests.in"
  outHandle <- openFile fullFp WriteMode
  inHandle <- openFile fullIn ReadMode
  let conf = ProgramConfig projectRoot ghcPath "/tests/exercises/" inHandle outHandle stderr
  watchTid <- forkIO (runExerciseWatch conf watchTestExercises)
  -- Modify Files
  makeModifications modifications
  killThread watchTid
  hClose outHandle
  hClose inHandle
  removeFile fullDest1
  removeFile fullDest2
  programOutput <- readFile fullFp
  return programOutput
  where
    addFullDirectory = (++) (projectRoot ++ "/tests/exercises/watcher_types/")
    fullDest1 = addFullDirectory "Types1.hs"
    fullDest2 = addFullDirectory "Types2.hs"
    modifications =
      [ (addFullDirectory "Types1Mod1.hs", fullDest1)
      , (addFullDirectory "Types1Mod2.hs", fullDest1)
      , (addFullDirectory "Types2Mod1.hs", fullDest2)
      , (addFullDirectory "Types2Mod2.hs", fullDest2)
      ]
