// Contender: Rust `nom` — a parser-COMBINATOR library, koru's Rust general-
// library peer (same category as parsec/FParsec; NOT a specialized JSON
// deserializer like serde). RECOGNIZER lane: it validates the full JSON
// grammar and returns the consumed span, building NO value tree — the matched
// lane against the koru std/parser recognizer and the zig hand-rolled
// recognizer. General RFC surface (whitespace anywhere), like the zig
// hand-rolled rival, where the koru grammar is comptime-specialized to the
// doc's dialect (the README's lane nuance).
//
// Repetition uses fold_many0_count-style folds (no Vec allocation) so the
// recognizer genuinely builds nothing. String escapes accept \uXXXX shape;
// the one leniency vs a full validator is that \u is not required to be
// followed by exactly 4 hex here — noted, and irrelevant to this ASCII corpus.
//
// Protocol identical to every contender: read the doc from the LAST argv, 3s
// in-process timed-pass loop, print `passes=<n> seconds=<s>`; on an invalid
// doc print `INVALID` and exit 1 (the suite's reject gate).
use nom::{
    branch::alt,
    character::complete::{char, one_of, satisfy},
    combinator::{opt, recognize},
    multi::fold_many0,
    sequence::{pair, preceded},
    IResult, Parser,
};
use std::time::{Duration, Instant};

fn ws(i: &str) -> IResult<&str, ()> {
    fold_many0(one_of(" \t\r\n"), || (), |_, _| ())(i)
}

fn jstring(i: &str) -> IResult<&str, ()> {
    let (i, _) = char('"')(i)?;
    let (i, _) = fold_many0(strchar, || (), |_, _| ())(i)?;
    let (i, _) = char('"')(i)?;
    Ok((i, ()))
}

fn strchar(i: &str) -> IResult<&str, ()> {
    alt((
        // escape: backslash then one escapable char (\uXXXX shape is lenient)
        preceded(char('\\'), one_of("\"\\/bfnrtu0123456789abcdefABCDEF"))
            .map(|_| ()),
        // any non-quote, non-backslash, non-control character
        satisfy(|c| c != '"' && c != '\\' && c >= ' ').map(|_| ()),
    ))(i)
}

fn number(i: &str) -> IResult<&str, ()> {
    let int = alt((
        recognize(char('0')),
        recognize(pair(
            satisfy(|c| ('1'..='9').contains(&c)),
            fold_many0(satisfy(|c| c.is_ascii_digit()), || (), |_, _| ()),
        )),
    ));
    let frac = opt(pair(
        char('.'),
        recognize(pair(
            satisfy(|c| c.is_ascii_digit()),
            fold_many0(satisfy(|c| c.is_ascii_digit()), || (), |_, _| ()),
        )),
    ));
    let exp = opt(pair(
        one_of("eE"),
        pair(
            opt(one_of("+-")),
            recognize(pair(
                satisfy(|c| c.is_ascii_digit()),
                fold_many0(satisfy(|c| c.is_ascii_digit()), || (), |_, _| ()),
            )),
        ),
    ));
    let (i, _) = recognize(pair(opt(char('-')), pair(int, pair(frac, exp))))(i)?;
    Ok((i, ()))
}

fn value(i: &str) -> IResult<&str, ()> {
    let (i, _) = ws(i)?;
    let c = i.chars().next().ok_or_else(|| {
        nom::Err::Error(nom::error::Error::new(i, nom::error::ErrorKind::Eof))
    })?;
    let (i, _) = match c {
        '"' => jstring(i)?,
        '{' => object(i)?,
        '[' => array(i)?,
        't' => (nom::bytes::complete::tag("true")(i)?.0, ()),
        'f' => (nom::bytes::complete::tag("false")(i)?.0, ()),
        'n' => (nom::bytes::complete::tag("null")(i)?.0, ()),
        _ => number(i)?,
    };
    Ok((i, ()))
}

fn object(i: &str) -> IResult<&str, ()> {
    let (i, _) = char('{')(i)?;
    let (i, _) = ws(i)?;
    if let Ok((i, _)) = char::<_, nom::error::Error<&str>>('}')(i) {
        return Ok((i, ()));
    }
    let mut i = i;
    loop {
        let (r, _) = ws(i)?;
        let (r, _) = jstring(r)?;
        let (r, _) = ws(r)?;
        let (r, _) = char(':')(r)?;
        let (r, _) = value(r)?;
        let (r, _) = ws(r)?;
        let c = r.chars().next().ok_or_else(|| {
            nom::Err::Error(nom::error::Error::new(r, nom::error::ErrorKind::Eof))
        })?;
        match c {
            ',' => {
                i = char(',')(r)?.0;
            }
            '}' => return Ok((char('}')(r)?.0, ())),
            _ => {
                return Err(nom::Err::Error(nom::error::Error::new(
                    r,
                    nom::error::ErrorKind::Char,
                )))
            }
        }
    }
}

fn array(i: &str) -> IResult<&str, ()> {
    let (i, _) = char('[')(i)?;
    let (i, _) = ws(i)?;
    if let Ok((i, _)) = char::<_, nom::error::Error<&str>>(']')(i) {
        return Ok((i, ()));
    }
    let mut i = i;
    loop {
        let (r, _) = value(i)?;
        let (r, _) = ws(r)?;
        let c = r.chars().next().ok_or_else(|| {
            nom::Err::Error(nom::error::Error::new(r, nom::error::ErrorKind::Eof))
        })?;
        match c {
            ',' => {
                i = char(',')(r)?.0;
            }
            ']' => return Ok((char(']')(r)?.0, ())),
            _ => {
                return Err(nom::Err::Error(nom::error::Error::new(
                    r,
                    nom::error::ErrorKind::Char,
                )))
            }
        }
    }
}

/// Whole-input recognize (like the koru entry): value then trailing ws then EOF.
fn recognize_json(doc: &str) -> bool {
    match value(doc) {
        Ok((rest, _)) => match ws(rest) {
            Ok((rest2, _)) => rest2.is_empty(),
            Err(_) => false,
        },
        Err(_) => false,
    }
}

fn main() {
    let path = std::env::args().nth(1).expect("usage: nom_recognize <doc.json>");
    let bytes = std::fs::read(&path).expect("read doc");
    let doc = String::from_utf8(bytes).expect("utf-8 doc");

    if !recognize_json(&doc) {
        println!("INVALID");
        std::process::exit(1);
    }

    let start = Instant::now();
    let deadline = Duration::from_secs(3);
    let mut passes: u64 = 0;
    let mut sink: u64 = 0;
    while start.elapsed() < deadline {
        // recognize_json returns bool; fold it into a sink so the optimizer
        // cannot elide the pass.
        sink = sink.wrapping_add(recognize_json(&doc) as u64);
        passes += 1;
    }
    let secs = start.elapsed().as_secs_f64();
    println!("passes={} seconds={:.6} sink={}", passes, secs, sink);
}
