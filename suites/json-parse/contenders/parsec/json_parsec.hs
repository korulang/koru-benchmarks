-- Contender: Haskell `parsec` — the canonical parser-COMBINATOR library
-- (combinators were born in Haskell), koru's truest general-library peer.
-- General-library CATEGORY (like koru, FParsec, nom); NOT a specialized
-- deserializer. Two WORK-DONE lanes from one grammar, selected by argv[1]:
--
--   recognize  -> validates structure, builds NO tree (returns ()), forced
--                 to completion by the trailing `eof`. Matched lane vs the
--                 koru std/parser recognizer and zig hand-rolled recognizer.
--   build      -> builds a JValue tree AND deepseq-forces it every pass, so
--                 the number `read`s, string conses, and list spines are all
--                 real work. Matched lane vs zig std.json Value / py json.loads
--                 (full-tree) — but general-library, not specialized.
--
-- Grammar is idiomatic parsec: `between`/`sepBy`/`lexeme`, RFC-8259 surface
-- (whitespace anywhere, \uXXXX escapes, full number grammar). Like the zig
-- hand-rolled rival it is GENERAL, where the koru grammar is comptime-
-- specialized to the doc's dialect — the same lane nuance the README records.
--
-- Protocol identical to every other contender: read the doc from the LAST
-- argv, run an in-process 3-wall-second timed-pass loop, print
-- `passes=<n> seconds=<s>`. On an invalid doc: print `INVALID` and exit 1
-- (the suite's reject gate). Stream type is strict ByteString (Char8) — the
-- fair, fast parsec stream, same library.
{-# LANGUAGE BangPatterns #-}
module Main (main) where

import qualified Data.ByteString.Char8 as BS
import           Text.Parsec
import           Text.Parsec.ByteString (Parser)
import           Control.DeepSeq        (NFData (..), deepseq)
import           Control.Exception      (evaluate)
import           Data.Time.Clock        (getCurrentTime, diffUTCTime)
import           System.Environment     (getArgs)
import           System.Exit            (exitFailure)
import           System.IO              (hSetBuffering, stdout, BufferMode (..))
import           Text.Printf            (printf)

-- ---- build-lane value tree ------------------------------------------------
data JValue
  = JNull
  | JBool !Bool
  | JNum  !Double
  | JStr  !String
  | JArr  ![JValue]
  | JObj  ![(String, JValue)]

instance NFData JValue where
  rnf JNull       = ()
  rnf (JBool b)   = b `seq` ()
  rnf (JNum n)    = n `seq` ()
  rnf (JStr s)    = rnf s
  rnf (JArr xs)   = rnf xs
  rnf (JObj kvs)  = rnf kvs

-- ---- shared lexing --------------------------------------------------------
ws :: Parser ()
ws = skipMany (oneOf " \t\r\n")

lexeme :: Parser a -> Parser a
lexeme p = p <* ws

symbol :: Char -> Parser ()
symbol c = lexeme (char c *> pure ())

-- string body (shared shape): opening quote already implied by caller.
stringChars :: Parser String
stringChars = do
  _ <- char '"'
  cs <- many strChar
  _ <- char '"'
  pure cs
  where
    strChar = (char '\\' *> escChar)
          <|> satisfy (\c -> c /= '"' && c /= '\\' && c >= ' ')
    escChar = choice
      [ '"'  <$ char '"',  '\\' <$ char '\\', '/'  <$ char '/'
      , '\b' <$ char 'b',  '\f' <$ char 'f',  '\n' <$ char 'n'
      , '\r' <$ char 'r',  '\t' <$ char 't'
      , char 'u' *> (hexToChar <$> count 4 hexDigit) ]
    hexToChar = toEnum . foldl (\a d -> a * 16 + hexVal d) 0
    hexVal d
      | d >= '0' && d <= '9' = fromEnum d - fromEnum '0'
      | d >= 'a' && d <= 'f' = fromEnum d - fromEnum 'a' + 10
      | otherwise            = fromEnum d - fromEnum 'A' + 10

-- number text (shared): the exact RFC number grammar, captured as a string.
numberStr :: Parser String
numberStr = do
  sgn  <- option "" (string "-")
  int  <- string "0" <|> ((:) <$> oneOf ['1'..'9'] <*> many digit)
  frac <- option "" ((:) <$> char '.' <*> many1 digit)
  ex   <- option "" expPart
  pure (sgn ++ int ++ frac ++ ex)
  where
    expPart = do
      e  <- oneOf "eE"
      sg <- option "" (string "+" <|> string "-")
      ds <- many1 digit
      pure (e : sg ++ ds)

-- ---- recognize lane: build nothing ---------------------------------------
sepByD :: Parser a -> Parser b -> Parser ()
sepByD p sep = optional (p *> skipMany (sep *> p))

jsonR :: Parser ()
jsonR = ws *> valueR <* eof

valueR :: Parser ()
valueR = lexeme $ do
  c <- lookAhead anyChar
  case c of
    '"' -> stringChars *> pure ()
    '{' -> objectR
    '[' -> arrayR
    't' -> string "true"  *> pure ()
    'f' -> string "false" *> pure ()
    'n' -> string "null"  *> pure ()
    _   -> numberStr *> pure ()
  where
    objectR = between (symbol '{') (char '}') (memberR `sepByD` symbol ',')
    arrayR  = between (symbol '[') (char ']') (valueR  `sepByD` symbol ',')
    memberR = lexeme (stringChars *> pure ()) *> symbol ':' *> valueR

-- ---- build lane: allocate the tree ---------------------------------------
jsonV :: Parser JValue
jsonV = ws *> valueV <* eof

valueV :: Parser JValue
valueV = lexeme $ do
  c <- lookAhead anyChar
  case c of
    '"' -> JStr  <$> stringChars
    '{' -> objectV
    '[' -> arrayV
    't' -> JBool True  <$ string "true"
    'f' -> JBool False <$ string "false"
    'n' -> JNull       <$ string "null"
    _   -> (JNum . read) <$> numberStr
  where
    objectV = JObj <$> between (symbol '{') (char '}') (memberV `sepBy` symbol ',')
    arrayV  = JArr <$> between (symbol '[') (char ']') (valueV  `sepBy` symbol ',')
    memberV = (,) <$> lexeme stringChars <* symbol ':' <*> valueV

-- ---- harness --------------------------------------------------------------
main :: IO ()
main = do
  hSetBuffering stdout LineBuffering
  args <- getArgs
  (mode, path) <- case args of
    [m, p] -> pure (m, p)
    [p]    -> pure ("build", p)
    _      -> error "usage: json_parsec <recognize|build> <doc.json>"
  doc <- BS.readFile path
  case mode of
    "recognize" -> gate (parse jsonR "" doc) >> timedLoop (stepR doc)
    "build"     -> gate (parse jsonV "" doc) >> timedLoop (stepV doc)
    _           -> error ("unknown mode: " ++ mode)
  where
    gate (Left _)  = putStrLn "INVALID" >> exitFailure
    gate (Right _) = pure ()

    -- The SourceName argument is threaded from `n`, so each pass is a fresh,
    -- unshared computation (GHC cannot CSE-hoist a constant parse out of the
    -- loop); the name only labels error positions, so parse WORK is identical.
    stepR doc n = case parse jsonR (show n) doc of
      Left e  -> error ("parse failed mid-loop: " ++ show e)
      Right _ -> 0 :: Int                    -- eof forces full consumption
    stepV doc n = case parse jsonV (show n) doc of
      Left e  -> error ("parse failed mid-loop: " ++ show e)
      Right v -> v `deepseq` 0 :: Int        -- force the whole tree

-- Drive a fully-forced pass repeatedly for 3 wall seconds. `evaluate (step n)`
-- forces each pass to WHNF in IO; `step` depends on n so nothing is shared.
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
