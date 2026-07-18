-- Contender: Haskell `megaparsec` — the modern successor to parsec, a parser-
-- COMBINATOR library, koru's general-library peer (same category as parsec /
-- nom / FParsec; NOT a specialized deserializer). RECOGNIZER lane: validates
-- the full JSON grammar and returns (), building NO tree — matched against the
-- koru std/parser recognizer and the other general-lib recognizers.
--
-- Grammar shape is deliberately IDENTICAL to the parsec entry (char-by-char
-- skipMany / first-char dispatch, full RFC surface) so the measurement isolates
-- library overhead on the SAME grammar — no megaparsec-only chunk tricks
-- (takeWhileP) that would change the grammar rather than the library. Builds
-- nothing: skipMany / skipSome discard, void on terminals. Stream is strict
-- `Text` (megaparsec's fast native stream; tokens are Char).
--
-- Protocol identical to every contender: read the doc from the LAST argv, 3s
-- in-process timed loop, print `passes=<n> seconds=<s>`; invalid doc -> print
-- `INVALID`, exit 1. Anti-sharing: the iteration counter is threaded through
-- parse's source-name arg so GHC cannot CSE-hoist a constant parse out of the
-- loop (the name only labels error positions; parse work is identical).
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE BangPatterns #-}
module Main (main) where

import           Data.Void          (Void)
import           Data.Text          (Text)
import qualified Data.Text.IO       as TIO
import           Text.Megaparsec
import           Text.Megaparsec.Char (char, string)
import           Control.Monad      (void)
import           Control.Exception  (evaluate)
import           Data.Time.Clock    (getCurrentTime, diffUTCTime)
import           System.Environment (getArgs)
import           System.Exit        (exitFailure)
import           System.IO          (hSetBuffering, stdout, BufferMode (..))
import           Text.Printf        (printf)

type Parser = Parsec Void Text

isDigit :: Char -> Bool
isDigit c = c >= '0' && c <= '9'

ws :: Parser ()
ws = skipMany (satisfy (\c -> c == ' ' || c == '\t' || c == '\r' || c == '\n'))

jstring :: Parser ()
jstring = do
  _ <- char '"'
  skipMany strChar
  void (char '"')
  where
    strChar = void (char '\\' >> escChar)
          <|> void (satisfy (\c -> c /= '"' && c /= '\\' && c >= ' '))
    escChar = void (satisfy (\c -> c `elem` ("\"\\/bfnrtu0123456789abcdefABCDEF" :: String)))

number :: Parser ()
number = do
  _ <- optional (char '-')
  void (char '0') <|> (satisfy (\c -> c >= '1' && c <= '9') >> skipMany (satisfy isDigit))
  _ <- optional (char '.' >> skipSome (satisfy isDigit))
  _ <- optional (oneOf ("eE" :: String) >> optional (oneOf ("+-" :: String)) >> skipSome (satisfy isDigit))
  pure ()

sepByD :: Parser () -> Parser () -> Parser ()
sepByD p sep = void $ optional (p >> skipMany (sep >> p))

value :: Parser ()
value = dispatch <* ws
  where
    dispatch = do
      c <- lookAhead anySingle
      case c of
        '"' -> jstring
        '{' -> object
        '[' -> array
        't' -> void (string "true")
        'f' -> void (string "false")
        'n' -> void (string "null")
        _   -> number
    object  = between (char '{' >> ws) (char '}') (member `sepByD` (char ',' >> ws))
    array   = between (char '[' >> ws) (char ']') (value  `sepByD` (char ',' >> ws))
    member  = (jstring >> ws) >> char ':' >> ws >> value

json :: Parser ()
json = ws *> value <* eof

main :: IO ()
main = do
  hSetBuffering stdout LineBuffering
  args <- getArgs
  let path = last args
  doc <- TIO.readFile path
  case parse json "" doc of
    Left _  -> putStrLn "INVALID" >> exitFailure
    Right _ -> pure ()
  timedLoop (step doc)
  where
    step doc n = case parse json (show n) doc of
      Left e  -> error ("parse failed mid-loop: " ++ errorBundlePretty e)
      Right _ -> 0 :: Int    -- eof forces full consumption

timedLoop :: (Int -> Int) -> IO ()
timedLoop step = do
  start <- getCurrentTime
  let go !n !acc = do
        now <- getCurrentTime
        let el = realToFrac (diffUTCTime now start) :: Double
        if el >= 3.0
          then do _ <- evaluate acc
                  printf "passes=%d seconds=%.6f\n" n el
          else do !r <- evaluate (step n)
                  go (n + 1) (acc + r)
  go 0 0
