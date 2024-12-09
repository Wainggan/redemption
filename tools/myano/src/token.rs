
use crate::error;

#[derive(Debug, PartialEq, Clone)]
pub enum Token {
	Eof,
	Semicolon,
	Integer(String),
	Float(String),
	Add,
	Sub,
	Star,
	Slash,
	Equal,
	EqualEqual,
	Lesser,
	Greater,
	LesserEqual,
	GreaterEqual,
	Bang,
	BangEqual,
	LParen,
	RParen,
}

impl std::fmt::Display for Token {
	fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
		write!(f,
			"({})",
			match self {
				Token::Eof => "<eof>",
				Token::Semicolon => ";",
				Token::Add => "+",
				Token::Sub => "-",
				Token::Star => "*",
				Token::Slash => "/",
				Token::Equal => "=",
				Token::EqualEqual => "==",
				Token::Lesser => "<",
				Token::Greater => ">",
				Token::LesserEqual => "<=",
				Token::GreaterEqual => ">=",
				Token::Bang => "!",
				Token::BangEqual => "!=",
				Token::LParen => "'('",
				Token::RParen => "')'",
				Token::Integer(n) => n,
				Token::Float(n) => n,
			},
		)
	}
}

pub fn tokenize(reporter: &mut error::Reporter, source: &str) -> Vec<Token> {
	let mut lexer = Lexer::new(source, reporter);
	lexer.run();
	lexer.tokens
}


struct Lexer<'a> {
	tokens: Vec<Token>,
	reporter: &'a mut error::Reporter,
	source: String,
	current: usize,
	start: usize,
}

impl Lexer<'_> {
	fn new<'a>(src: &str, reporter: &'a mut error::Reporter) -> Lexer<'a> {
		Lexer {
			tokens: Vec::new(),
			reporter,
			source: src.to_string(),
			current: 0,
			start: 0,
		}
	}

	fn at_end(&self) -> bool {
		self.current >= self.source.len()
	}

	fn get(&self, at: usize) -> Option<char> {
		self.source.chars().nth(at)
	}
	fn peek_offset(&self, offset: usize) -> Option<char> {
		if self.at_end() {
			None
		} else {
			self.get(self.current + offset)
		}
	}
	fn peek(&self) -> Option<char> {
		self.peek_offset(0)
	}
	fn advance(&mut self) -> Option<char> {
		if self.current == self.source.len() {
			return None;
		}
		let out = self.get(self.current);
		self.current += 1;
		return out;
	}

	fn compare(&mut self, expected: char) -> bool {
		if self.at_end() {
			return false;
		}
		if self.get(self.current) != Some(expected) {
			return false;
		}
		self.current += 1;
		return true;
	}

	fn is_number(&self, c: Option<char>) -> bool {
		match c {
			None => false,
			Some(c) => c.is_numeric()
		}
	}
	fn is_whitespace(&self, c: Option<char>) -> bool {
		match c {
			None => false,
			Some(c) => c.is_whitespace()
		}
	}

	fn add(&mut self, token: Token) {
		self.tokens.push(token);
	}

	fn consume_whitespace(&mut self) {
		while self.is_whitespace(self.peek()) {
			self.advance();
		}
	}

	fn consume_number(&mut self) -> Token {
		while self.is_number(self.peek()) {
			self.advance();
		}
		if self.peek() == Some('.') {
			self.advance();
			while self.is_number(self.peek()) {
				self.advance();
			}
			Token::Float(self.source[self.start..self.current].to_string())
		} else {
			Token::Integer(self.source[self.start..self.current].to_string())
		}
	}

	fn next(&mut self) {
		self.start = self.current;

		let c = match self.advance() {
			None => return,
			Some(c) => c,
		};

		match c {
			';' => self.add(Token::Semicolon),

			'+' => self.add(Token::Add),
			'-' => self.add(Token::Sub),
			'*' => self.add(Token::Star),
			'/' => self.add(Token::Slash),

			'!' => if self.compare('=') {
				self.add(Token::BangEqual)
			} else {
				self.add(Token::Bang)
			},
			'=' => if self.compare('=') {
				self.add(Token::EqualEqual)
			} else {
				self.add(Token::Equal)
			},

			'<' => if self.compare('=') {
				self.add(Token::LesserEqual)
			} else {
				self.add(Token::Lesser)
			},
			'>' => if self.compare('=') {
				self.add(Token::GreaterEqual)
			} else {
				self.add(Token::Greater)
			},

			'(' => self.add(Token::LParen),
			')' => self.add(Token::RParen),

			_ => {
				if c.is_whitespace() {
					self.consume_whitespace();
					return;
				}
				if c.is_numeric() {
					let token = self.consume_number();
					self.add(token);
					return;
				}
				self.reporter.error(format!("unknown character: {}", c));
			}
		}

	}

	fn run(&mut self) {
		while !self.at_end() {
			self.next();
		}
		self.add(Token::Eof);
	}
}

