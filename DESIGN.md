# Design Document: Anki Spelling Words Package

## Project Overview

This package automates the creation and updating of Anki (APKG) flashcard decks for spelling test preparation. It generates cards with audio pronunciations and definitions, suitable for elementary and middle school spelling bee practice.

**Target Platform**: Ubuntu 24.04
**Language**: Python 3.x
**Package Manager**: uv

## Recommended Third-Party Packages

This project leverages established, well-maintained Python packages rather than implementing custom solutions:

### Core Dependencies

- **genanki** - Generate Anki decks programmatically (replaces custom APKG manager)
  - Handles APKG file creation, SQLite database, media files, and compression
  - Well-tested library with 2K+ GitHub stars
  - Latest release: November 2023

- **requests-cache** - Persistent HTTP caching for requests
  - Provides transparent caching with multiple backend options (SQLite, filesystem, etc.)
  - Supports cache expiration and HTTP cache-control headers
  - Latest release: June 2024 (v1.2.1)

- **pydantic-settings** - Settings management with environment variables
  - Type-safe configuration loading from .env files
  - Automatic validation of required settings
  - Integrates seamlessly with pydantic for data validation

- **click** - Composable command-line interfaces
  - Decorator-based CLI framework
  - Built-in help generation, parameter validation
  - Industry standard for Python CLIs

- **rich** - Beautiful console output and progress bars
  - Colored text, tables, progress bars, and panels
  - Better than basic print() for user-facing CLI
  - Integrates well with click

- **loguru** - Simplified Python logging
  - Pre-configured with sensible defaults
  - Automatic exception logging with full context
  - Simpler API than Python's standard logging module

- **pydub** - Audio file manipulation
  - Simple API for loading, concatenating, and converting audio
  - Requires ffmpeg system dependency

- **requests** - HTTP client for API calls
  - Industry standard for HTTP requests
  - Works seamlessly with requests-cache

### Development Dependencies

- **pytest** - Testing framework
- **pytest-cov** - Code coverage reporting
- **ruff** - Fast Python linter and formatter (replaces flake8, black, isort)
- **pre-commit** - Git hook framework for running checks before commits

## System Architecture

### High-Level Components

```
┌─────────────────┐
│  Word List      │
│  Input          │
└────────┬────────┘
         │
         v
┌─────────────────┐     ┌──────────────────┐
│  Dictionary     │────▶│  Audio           │
│  API Client     │     │  Downloader      │
└────────┬────────┘     └────────┬─────────┘
         │                       │
         │  (definition)         │  (audio files)
         │                       │
         v                       v
┌─────────────────────────────────────────┐
│  Audio Processor                        │
│  - Concatenate multiple pronunciations  │
│  - Add 1-second gaps                    │
│  - Convert to compatible format         │
└────────────────┬────────────────────────┘
                 │
                 v
┌─────────────────────────────────────────┐
│  APKG Manager                           │
│  - Read existing APKG                   │
│  - Update notes table                   │
│  - Update media files                   │
│  - Recompress and package               │
└─────────────────────────────────────────┘
                 │
                 v
┌─────────────────┐
│  Output APKG    │
└─────────────────┘
```

## Core Components

### 1. Word List Manager (`spelling_words/word_list.py`)

**Purpose**: Handle input of word lists

**Responsibilities**:
- Read word lists from file (TXT only, newline separated)
- Validate word format (alphabetic with hyphens/apostrophes allowed)
- Remove duplicates while preserving order

**Implementation**: Simple Python class with file I/O and validation logic

**MVP**: Text file input (one word per line)

### 2. Configuration Manager (`spelling_words/config.py`)

**Purpose**: Manage application configuration from environment variables

**Technology**: **pydantic-settings**

**Responsibilities**:
- Load API keys from `.env` file with type validation
- Provide validated configuration throughout application
- Raise clear errors for missing required settings

**Environment Variables**:
- `MW_ELEMENTARY_API_KEY`: Merriam-Webster Elementary Dictionary API key (required)
- `MW_COLLEGIATE_API_KEY`: Merriam-Webster Collegiate Dictionary API key (optional, future)
- `CACHE_DIR`: Cache directory path (optional, default: `.cache/`)

**Note**: We have a limit of 1000 API calls per day for Merriam-Webster.

### 3. Dictionary API Client (`spelling_words/dictionary_client.py`)

**Purpose**: Fetch word definitions and audio URLs with automatic caching

**Technology**: **requests** + **requests-cache**

**Responsibilities**:
- Query Merriam-Webster Elementary Dictionary API
- Parse API responses for definitions and audio URLs
- Automatic HTTP caching (configured via requests-cache)
- Handle API errors and timeouts with retry logic
- Extract multiple pronunciation variants

**Data Retrieved**:
- Word definitions (simplified for flashcards)
- Audio file URLs (may be multiple for different pronunciations)
- Pronunciation symbols (future)
- Etymology/language tips (future)

**Caching Strategy**: requests-cache with SQLite backend caches all 2xx responses persistently

### 4. Audio Downloader (`spelling_words/audio_downloader.py`)

**Purpose**: Download and cache audio files

**Technology**: **requests** + **requests-cache**

**Responsibilities**:
- Download audio files from URLs with automatic caching
- Validate audio content (check Content-Type headers)
- Handle network errors with exponential backoff retry
- MVP: Download first pronunciation only

**Caching**: Leverages requests-cache for automatic HTTP-level caching

### 5. Audio Processor (`spelling_words/audio_processor.py`)

**Purpose**: Process and format audio for Anki

**Technology**: **pydub** (requires **ffmpeg** system dependency)

**Responsibilities**:
- Load and validate audio files
- Concatenate multiple pronunciations with 1-second gaps (Phase 2)
- Convert to MP3 format with consistent bitrate (128k)
- Generate sanitized filenames

**MVP**: Simple pass-through or basic MP3 conversion

### 6. APKG Manager (`spelling_words/apkg_manager.py`)

**Purpose**: Generate Anki deck packages

**Technology**: **genanki**

**Responsibilities**:
- Create Anki Model (card template) for spelling words
- Generate Notes with word, definition, and audio
- Add media files (audio) to package
- Export as .apkg file

**Benefits of genanki**:
- Eliminates need for manual SQLite operations
- Handles Zstandard compression automatically
- Manages media file indexing
- Well-tested with the Anki ecosystem

**Note**: This replaces the complex custom APKG manager with a simple wrapper around genanki

### 7. CLI (`spelling_words/cli.py`)

**Purpose**: Command-line interface

**Technology**: **click** + **rich**

**Responsibilities**:
- Parse command-line arguments
- Display rich progress bars (via rich)
- Orchestrate the processing workflow
- Display colored, formatted output
- Handle errors gracefully with user-friendly messages

## Card Structure

### Front of Card (Question)

```
[sound:word_combined.mp3]

Definition: <word definition from dictionary>
```

**Future Enhancements**:
- Etymology
- Usage examples
- Part of speech

### Back of Card (Answer)

```
word
```

Where `word` is the lowercase spelling.

**Future Enhancements**:
- Headscratcher language tips
- Pronunciation symbols (IPA)
- Spelling suggestions/hints

## Development Phases

### Phase 1: MVP (Minimum Viable Product)

**Goal**: Create basic APKG files with audio and definitions

**Features**:
- Read word list from simple text file (one word per line)
- Query Merriam-Webster Elementary Dictionary API
- Download single pronunciation audio file per word
- Extract basic definition
- Create new APKG file with notes containing:
  - Audio reference on front
  - Definition on front
  - Lowercase word on back
- Basic error handling and logging

**Deliverables**:
- Working Python package installable via uv
- Command-line interface (CLI) for basic usage
- `.env.example` file with required API keys
- Basic documentation

**Success Criteria**:
- Can process a list of 100 or more common spelling words
- Generates valid APKG file loadable in AnkiDroid
- Cards display audio and definition correctly
- Reduces redundant downloads and API calls via agressive local caching for any 2xx returned call.  Persist to disk.
- If not operating in an environment where .env shows LOCAL_TESTING=True, only allow for one API call per test as cache won't persist across testing runs.

#### MVP Implementation Tasks

**1. Project Setup**
- [ ] Initialize project with uv (`uv init`)
- [ ] Create project structure:
  ```
  spelling_words/
  ├── __init__.py
  ├── __main__.py
  ├── cli.py
  ├── config.py
  ├── word_list.py
  ├── dictionary_client.py
  ├── audio_processor.py
  └── apkg_manager.py
  tests/
  └── fixtures/
      └── test_words.txt
  ```
- [ ] Set up `pyproject.toml` with dependencies:
  - Core: `genanki`, `requests-cache`, `pydantic-settings`, `click`, `rich`, `loguru`, `pydub`, `requests`
  - Dev: `pytest`, `pytest-cov`, `ruff`, `pre-commit`
- [ ] Configure CLI entry point in `pyproject.toml`
- [ ] Configure ruff settings in `pyproject.toml` (linting rules, formatting)
- [ ] Create `.pre-commit-config.yaml` with ruff hooks
- [ ] Install pre-commit hooks: `uv run pre-commit install`
- [ ] Update `.gitignore` (already includes `.env`)
- [ ] Verify ffmpeg is documented in README_LLM.md

**2. Configuration Module (`spelling_words/config.py`)**
- [ ] Create `Settings` class inheriting from `pydantic_settings.BaseSettings`
- [ ] Define fields:
  - [ ] `mw_elementary_api_key: str` (required)
  - [ ] `cache_dir: str = ".cache/"` (optional with default)
- [ ] Configure to load from `.env` file: `model_config = SettingsConfigDict(env_file='.env')`
- [ ] Create `get_settings()` function that returns singleton Settings instance
- [ ] Settings will automatically validate and raise clear errors if required fields missing

**3. Logging Setup (`spelling_words/__init__.py`)**
- [ ] Import and configure loguru logger
- [ ] Set default log format with timestamps
- [ ] Configure log level (INFO by default, DEBUG if --verbose)
- [ ] Add exception hook to automatically log uncaught exceptions with full context

**4. Word List Manager (`spelling_words/word_list.py`)**
- [ ] Create `WordListManager` class
- [ ] Implement `load_from_file(file_path: str) -> list[str]`:
  - [ ] Read file with proper encoding handling
  - [ ] Strip whitespace, skip empty lines
  - [ ] Convert to lowercase
  - [ ] Validate format (alphabetic + hyphens/apostrophes)
  - [ ] Raise `FileNotFoundError` or `ValueError` as appropriate
- [ ] Implement `remove_duplicates(words: list[str]) -> list[str]`:
  - [ ] Use `dict.fromkeys()` to preserve order
  - [ ] Log count of duplicates removed
- [ ] Use loguru for all logging

**5. HTTP Session with Caching (`spelling_words/dictionary_client.py`)**
- [ ] Import `requests_cache`
- [ ] Create cached session:
  ```python
  session = requests_cache.CachedSession(
      'spelling_words_cache',
      backend='sqlite',
      expire_after=timedelta(days=30)
  )
  ```
- [ ] Use this session for all HTTP requests (API and audio downloads)
- [ ] Caching is automatic - no manual cache checking needed!

**6. Dictionary API Client (`spelling_words/dictionary_client.py`)**
- [ ] Create `MerriamWebsterClient` class
- [ ] `__init__(api_key: str, session: CachedSession)`:
  - [ ] Validate API key is non-empty (raise `ValueError`)
  - [ ] Store session and base URL
- [ ] Implement `get_word_data(word: str) -> dict | None`:
  - [ ] Make GET request using cached session (automatic caching!)
  - [ ] URL: `f"https://dictionaryapi.com/api/v3/references/sd/json/{word}"`
  - [ ] Timeout: 10 seconds
  - [ ] Retry on `requests.Timeout` (max 3 attempts, exponential backoff)
  - [ ] Return None if word not found (check for suggestions response)
  - [ ] Use loguru for logging
- [ ] Implement `extract_definition(word_data: dict) -> str`:
  - [ ] Parse JSON structure for first definition
  - [ ] Simplify for flashcard use
  - [ ] Raise `ValueError` if no definition found
- [ ] Implement `extract_audio_urls(word_data: dict) -> list[str]`:
  - [ ] Parse JSON for audio references
  - [ ] Build full URLs with proper subdirectory handling
  - [ ] Return empty list if no audio

**7. Audio Processor (`spelling_words/audio_processor.py`)**
- [ ] Create `AudioProcessor` class
- [ ] Implement `download_audio(url: str, session: CachedSession) -> bytes | None`:
  - [ ] Use cached session (automatic caching!)
  - [ ] Retry on timeout (max 3 attempts)
  - [ ] Validate Content-Type header
  - [ ] Return bytes or None
- [ ] Implement `process_audio(audio_bytes: bytes, word: str) -> tuple[str, bytes]`:
  - [ ] Load with pydub `AudioSegment.from_file()`
  - [ ] Convert to MP3 with 128k bitrate
  - [ ] Generate sanitized filename: `f"{word.replace(' ', '_')}.mp3"`
  - [ ] Return (filename, mp3_bytes)
  - [ ] Catch `pydub.exceptions.CouldntDecodeError` and raise specific error

**8. APKG Manager (`spelling_words/apkg_manager.py`)**
- [ ] Import genanki
- [ ] Create Anki Model for spelling cards:
  ```python
  SPELLING_MODEL = genanki.Model(
      1607392319,  # Random model ID
      'Spelling Word Model',
      fields=[
          {'name': 'Audio'},
          {'name': 'Definition'},
          {'name': 'Word'},
      ],
      templates=[
          {
              'name': 'Spelling Card',
              'qfmt': '{{Audio}}<br><br>{{Definition}}',  # Front
              'afmt': '{{FrontSide}}<hr>{{Word}}',         # Back
          },
      ])
  ```
- [ ] Create `APKGBuilder` class:
  - [ ] `__init__(deck_name: str, output_path: str)`:
    - [ ] Create `genanki.Deck` instance
    - [ ] Initialize media files list
  - [ ] `add_word(word: str, definition: str, audio_filename: str, audio_data: bytes)`:
    - [ ] Create `genanki.Note` with SPELLING_MODEL
    - [ ] Add to deck
    - [ ] Track media file
  - [ ] `build()`:
    - [ ] Create `genanki.Package` with deck and media files
    - [ ] Call `package.write_to_file(output_path)`
    - [ ] That's it! genanki handles everything else.

**9. Command-Line Interface (`spelling_words/cli.py`)**
- [ ] Use `@click.command()` decorator pattern
- [ ] Define options:
  - [ ] `@click.option('--words', '-w', required=True, help='Path to word list file')`
  - [ ] `@click.option('--output', '-o', default='output.apkg', help='Output APKG path')`
  - [ ] `@click.option('--verbose', '-v', is_flag=True, help='Enable debug logging')`
- [ ] Implement main workflow:
  - [ ] Load settings with `get_settings()`
  - [ ] Configure loguru log level based on --verbose
  - [ ] Create cached session with requests_cache
  - [ ] Initialize components (WordListManager, MerriamWebsterClient, AudioProcessor, APKGBuilder)
  - [ ] Load and deduplicate word list
  - [ ] Use `rich.progress.track()` for progress bar:
    ```python
    from rich.progress import track
    for word in track(words, description="Processing words..."):
        # process word
    ```
  - [ ] For each word (with error handling):
    - [ ] Fetch word data
    - [ ] Extract definition and audio URLs
    - [ ] Download and process first audio
    - [ ] Add to APKG builder
    - [ ] Use `try/except` to log and skip failures
  - [ ] Build APKG file
  - [ ] Use `rich.console.Console()` to print summary with colors
- [ ] Handle missing .env with friendly error message

**10. Package Entry Points**
- [ ] `spelling_words/__init__.py`:
  - [ ] Set `__version__ = "0.1.0"`
  - [ ] Configure loguru
  - [ ] Export main classes
- [ ] `spelling_words/__main__.py`:
  - [ ] Import and call CLI main function
  - [ ] Enables `python -m spelling_words`

**11. Testing and Validation**
- [ ] Create `tests/fixtures/test_words.txt` with 5-10 common words
- [ ] Manual testing sequence:
  - [ ] Run: `uv run python -m spelling_words -w tests/fixtures/test_words.txt -o test.apkg`
  - [ ] Verify APKG created
  - [ ] Check cache directory has SQLite database
  - [ ] Run again - should be much faster (cached)
  - [ ] Load test.apkg in AnkiDroid
  - [ ] Verify cards show audio, definition, and word
  - [ ] Test with 100+ word list for scalability
- [ ] Verify no secrets in git history

**12. Documentation**
- [ ] Create `README_LLM.md` with:
  - [ ] Installation: uv setup, ffmpeg requirement
  - [ ] Configuration: .env setup with API keys
  - [ ] Usage examples
  - [ ] Development setup
- [ ] Add docstrings to all functions (Google-style)
- [ ] Add inline comments for complex logic (audio URL parsing, etc.)

### Phase 2: Enhanced Audio Processing

**Goal**: Handle multiple pronunciations and improve audio quality

**Features**:
- Download multiple pronunciations when available
- Concatenate pronunciations with 1-second gaps
- Audio format conversion and validation
- Fallback to Collegiate Dictionary API
- Audio caching to avoid re-downloads

**Deliverables**:
- Enhanced audio processing module
- Cache management
- Improved error handling for API failures

**Success Criteria**:
- Correctly handles words with 2+ pronunciations
- Gracefully falls back between API sources
- Reduces redundant downloads via caching

### Phase 3: APKG Update Support

**Goal**: Update existing APKG files instead of creating new ones

**Features**:
- Read existing APKG files
- Extract current notes and media
- Add new words without duplicating existing ones
- Preserve existing card scheduling data
- Update media index correctly

**Deliverables**:
- APKG update functionality
- Duplicate detection
- Preserves user study progress

**Success Criteria**:
- Can add 10 new words to existing 50-card deck
- No data loss or corruption
- Scheduling information preserved

### Phase 4: Enhanced Card Content

**Goal**: Add richer information to cards

**Features**:
- Pronunciation symbols (IPA)
- Etymology information
- Usage examples
- Language tips ("headscratchers")
- Spelling suggestions/patterns
- Part of speech

**Deliverables**:
- Enhanced card templates
- Additional data extraction from APIs
- Configurable card fields

**Success Criteria**:
- Cards include at least 3 additional data points
- Information displayed clearly in AnkiDroid
- Helps students better understand words

### Phase 5: Advanced Features

**Goal**: Production-ready features and polish.  I.e. we aren't doing this in 2025.  Probably not ever.

**Features**:
- Multiple input formats (CSV, JSON, Google Sheets integration)
- Batch processing optimizations
- Rate limiting and API quota management
- Text-to-Speech fallback for missing audio
- Progress reporting and detailed logging
- Configuration file support
- Word list validation (spell checking, difficulty levels)
- Custom card templates

**Deliverables**:
- Comprehensive CLI with all options
- Detailed logging and diagnostics
- Production documentation
- Test suite

## Technical Decisions

### Why MP3 for Audio?

- Widely supported by Anki/AnkiDroid
- Good compression ratio
- Simpler than 3GP conversion
- Supported by pydub with minimal configuration

### Why Zstandard?

- Required by APKG format (collection.anki21b)
- Efficient compression/decompression
- Well-supported Python library available

### Why SQLite?

- Required by APKG format
- Built-in Python support (sqlite3 module)
- Lightweight and efficient

### Why uv?

- Fast Python package management
- Modern dependency resolution
- Simpler than traditional pip/virtualenv workflow
- Good for reproducible builds

## Error Handling Strategy

Per project coding standards:

1. **Raise specific exception types** (not generic `Exception`)
2. **Try/catch only for known, resolvable exceptions**
3. **Log raised errors with full stack traces**
4. **Validate inputs early** (word lists, API keys, file paths)
5. **FAIL FAST** If we hit a problem, fail loud and clearly.  Everything should be cached, so we generally shouldn't mind reprocessing from the start
6. **Log Stack Traces**.  If raising an error using the logging package, be sure to use .exception rather than .error for unhandled errors so we see a stack trace.

## Testing Strategy

**Phase 1 (MVP)**:
- Verify APKG loads in AnkiDroid
- Unit tests for each component
- Integration tests for full workflow (use wordlist.txt in the repo root)
- Test with various edge cases:
  - Words not found in dictionary
  - Words with special characters
  - Very long word lists
  - API failures/timeouts
  - Corrupted APKG files

## Security Considerations

1. **API Keys**: Never commit to version control, use `.env` file
2. **Input Validation**: Sanitize word inputs to prevent injection
3. **File Paths**: Validate paths to prevent directory traversal
4. **SQL**: Use parameterized queries to prevent SQL injection

## Future Enhancements (Beyond Phase 5)

- Web interface for non-technical users
- Cloud storage integration (Google Drive, Dropbox)
- Collaborative word lists
- Pre-built word lists (grade level, spelling bee competitions)
- Mobile app for direct integration with AnkiDroid
- Support for other Anki platforms (desktop, iOS)
