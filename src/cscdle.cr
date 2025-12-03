require "kemal"
require "cscdle_words"

# ==========================================================
# CRYSTAL GAME LOGIC (BACK-END)
# ==========================================================

WORDS = CSCdleWords::WORDS
WORD_LENGTH = WORDS.first.size
MAX_GUESSES = 6

ENGLISH_WORDS = CSCdleWords.load_english_words(WORD_LENGTH)

class Game
  @@target_word : String        = WORDS.sample || WORDS.first
  @@guesses     : Array(String) = [] of String

  def self.reset
    @@target_word = WORDS.sample || WORDS.first
    @@guesses.clear
  end

  def self.target_word : String
    @@target_word
  end

  def self.guesses : Array(String)
    @@guesses
  end

  def self.add_guess(guess : String)
    @@guesses << guess
  end

  def self.win? : Bool
    @@guesses.last? == @@target_word
  end

  def self.over? : Bool
    win? || @@guesses.size >= MAX_GUESSES
  end
end

Game.reset

# ==========================================================
# SCORING LOGIC — WORDLE
# ==========================================================

def score_guess(guess : String) : Array(String)
  guess_chars  = guess.chars
  target_chars = Game.target_word.chars
  statuses = Array(String).new(guess_chars.size) { "absent" }

  guess_chars.each_with_index do |ch, i|
    if ch == target_chars[i]
      statuses[i] = "correct"
      target_chars[i] = '*'
    end
  end

  guess_chars.each_with_index do |ch, i|
    next if statuses[i] == "correct"
    if idx = target_chars.index(ch)
      statuses[i] = "present"
      target_chars[idx] = '*'
    end
  end

  statuses
end

# ==========================================================
# FRONT-END HELPERS
# ==========================================================

def build_grid_html : String
  String.build do |io|
    MAX_GUESSES.times do |row|
      guess = Game.guesses[row]?
      statuses = guess ? score_guess(guess) : nil

      io << "<div class=\"row\">"

      WORD_LENGTH.times do |col|
        char = ""
        css  = "empty"

        if guess && statuses
          char = guess[col].to_s.upcase
          css  = statuses[col]
        end

        io << "<div class=\"tile #{css}\">#{char}</div>"
      end

      io << "</div>"
    end
  end
end

def build_share_text : String
  String.build do |io|
    guesses = Game.guesses
    header = Game.win? ? "CSCdle #{guesses.size}/#{MAX_GUESSES}" : "CSCdle X/#{MAX_GUESSES}"
    io << header << "\n"

    guesses.each do |g|
      score_guess(g).each do |st|
        io << (st == "correct" ? "🟩" : st == "present" ? "🟨" : "⬛")
      end
      io << "\n"
    end
  end
end

# ==========================================================
# ROUTES
# ==========================================================

get "/" do |env|
  env.response.content_type = "text/html"

  error_msg = env.params.query["error"]?
  grid_html = build_grid_html

  status_text =
    if Game.guesses.empty?
      "Guess the #{WORD_LENGTH}-letter word."
    elsif Game.win?
      "You solved it in #{Game.guesses.size} tries!"
    elsif Game.over?
      "Out of guesses! The answer was <strong>#{Game.target_word.upcase}</strong>."
    else
      "Guesses left: #{MAX_GUESSES - Game.guesses.size}"
    end

  modal_html = ""

  if Game.over?
    modal_html = <<-MODAL
<div id="result-modal" class="modal show">
  <div class="modal-content">

    <h2>RESULT</h2>
    <p>#{Game.win? ? "Congratulations!" : "Try again!"}</p>

    <textarea id="share-box" readonly>#{build_share_text}</textarea>

    <button class="copy-btn" onclick="copyShare()">Copy</button>

    <form method="post" action="/new">
      <button class="play-btn" type="submit">Play Again</button>
    </form>

  </div>
</div>
MODAL
  end

  # ==========================================================
  # HTML + CSS + JS
  # ==========================================================
  <<-HTML
  <!doctype html>
  <html>
  <head>
    <meta charset="utf-8">
    <title>CSCdle</title>

    <style>
      body {
        margin: 0; background: #121213; color: white;
        font-family: system-ui; display: flex;
        justify-content: center; align-items: center;
        min-height: 100vh;
      }
      .game { text-align: center; }
      h1 { font-size: 2rem; letter-spacing: .15em; }

      .row { display: flex; justify-content: center; }
      .tile {
        width: 52px; height: 52px; margin: 2px;
        border: 2px solid #3a3a3c;
        display: flex; justify-content: center; align-items: center;
        font-size: 1.6rem; font-weight: bold; text-transform: uppercase;
      }
      .tile.empty { background: #121213; }
      .tile.absent { background: #3a3a3c; }
      .tile.present { background: #b59f3b; }
      .tile.correct { background: #538d4e; }

      .modal {
        position: fixed; inset: 0; background: rgba(0,0,0,0.55);
        display: none; justify-content: center; align-items: center;
      }
      .modal.show { display: flex; }

      .modal-content {
        background: #1f1f1f; padding: 20px; width: 320px;
        border-radius: 12px; text-align: center;
      }

      #share-box {
        width: 100%; height: 100px;
        background: #121213; color: white;
        border: 1px solid #333; border-radius: 6px;
        padding: 8px; margin-top: 10px;
      }

      .copy-btn {
        width: 100%;
        background: #538d4e;
        color: white;
        padding: 10px;
        border: none;
        border-radius: 6px;
        font-weight: bold;
        margin-top: 10px;
        cursor: pointer;
      }

      .play-btn {
        width: 100%;
        background: white;
        color: black;
        padding: 10px;
        border: none;
        border-radius: 6px;
        font-weight: bold;
        margin-top: 12px;
        cursor: pointer;
      }
    </style>

    <script>
      function copyShare(){
        var box = document.getElementById("share-box");
        box.select();
        document.execCommand("copy");
        alert("Copied!");
      }
    </script>

  </head>

  <body>
    <div class="game">

      <h1>CSCdle</h1>

      <div class="board">#{grid_html}</div>

      <form method="post" action="/guess">
        <input type="text" name="guess" maxlength="#{WORD_LENGTH}" minlength="#{WORD_LENGTH}" required>
        <button>Guess</button>
      </form>

      <div class="status">#{status_text}</div>
      #{error_msg ? "<div style='color:#f55'>#{error_msg}</div>" : ""}

      #{modal_html}

    </div>
  </body>
  </html>
  HTML
end

# ==========================================================
# POST ROUTES
# ==========================================================

post "/guess" do |env|
  guess = env.params.body["guess"].to_s.downcase.strip

  unless ENGLISH_WORDS.includes?(guess)
    next env.redirect "/?error=Invalid+English+word"
  end

  Game.add_guess(guess) unless Game.over?
  env.redirect "/"
end

post "/new" do |env|
  Game.reset
  env.redirect "/"
end

Kemal.run