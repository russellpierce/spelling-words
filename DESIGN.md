# Design Document: Anki Spelling Words Package

## Project Overview

This package automates the creation and updating of Anki (APKG) flashcard decks for spelling test preparation. It generates cards with audio pronunciations and definitions, suitable for elementary and middle school spelling bee practice.

**Target Platform**: Ubuntu 24.04
**Language**: Python 3.x
**Package Manager**: uv

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

### 1. Word List Manager

**Purpose**: Handle input of word lists

**Responsibilities**:
- Read word lists from file (TXT only, new line seperated)
- Validate word format
- Handle duplicates

**MVP**: Simple text file input (one word per line)

### 2. Dictionary API Client

**Purpose**: Fetch word definitions and audio URLs

**Responsibilities**:
- Query Merriam-Webster Elementary Dictionary API (primary)
- Fallback to Merriam-Webster Collegiate Dictionary API
- Parse API responses
- Extract definitions, audio URLs, and pronunciation variants
- Handle API errors and rate limiting
- Manage API key from environment variables

N.b. we have a limit of 1000 API calls per day.

**Data Retrieved**:
- Word definitions
- Audio file URLs (may be multiple for different pronunciations)
- Pronunciation symbols (future)
- Etymology/language tips (future)

### 3. Audio Downloader

**Purpose**: Download audio files from dictionary APIs

**Responsibilities**:
- Download audio files from URLs
- Handle multiple pronunciations per word
- Cache downloaded files
- Validate audio file format
- Handle network errors with retry logic

### 4. Audio Processor

**Purpose**: Process and format audio for Anki

**Responsibilities**:
- Load audio files (MP3, WAV, etc.)
- Concatenate multiple pronunciations with 1-second gaps
- Convert to target format (MP3 recommended)
- Normalize audio levels (optional, future enhancement)
- Generate unique filenames

**Dependencies**: pydub, ffmpeg (system)

### 5. APKG Manager

**Purpose**: Create or update APKG files

**Responsibilities**:
- Read and decompress existing APKG files
- Parse SQLite database (collection.anki21b)
- Extract model ID from existing notes
- Generate new note IDs (millisecond timestamp)
- Generate GUIDs (random 10-character strings)
- Format note fields with `\x1f` separator
- Update notes table in SQLite database
- Manage media index mapping
- Compress media files with Zstandard
- Recompress SQLite database
- Package everything into new APKG file

**Key Operations**:
- Decompress: `zstandard.ZstdDecompressor()`
- Compress: `zstandard.ZstdCompressor()`
- Database: `sqlite3` module
- Archive: `zipfile` module

### 6. Configuration Manager

**Purpose**: Manage application configuration

**Responsibilities**:
- Load API keys from `.env` file
- Provide configuration access throughout application
- Validate required configuration

**Environment Variables**:
- `MW_ELEMENTARY_API_KEY`: Merriam-Webster Elementary Dictionary API key
- `MW_COLLEGIATE_API_KEY`: Merriam-Webster Collegiate Dictionary API key (fallback)

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

#### MVP Implementation Tasks

**1. Project Setup**
- [ ] Initialize project with uv (`uv init`)
- [ ] Create project structure (directories for `spelling_words/`, `tests/`, etc.)
- [ ] Set up `pyproject.toml` with project metadata and dependencies
- [ ] Add initial dependencies: `zstandard`, `pydub`, `requests`, `python-dotenv`
- [ ] Create `.gitignore` (already exists, includes `.env`)
- [ ] Verify ffmpeg system dependency is documented in setup instructions

**2. Configuration Module (`spelling_words/config.py`)**
- [ ] Create `Config` class to load environment variables
- [ ] Load API keys from `.env` file using `python-dotenv`
- [ ] Validate that `MW_ELEMENTARY_API_KEY` is present and non-empty
- [ ] Provide default cache directory path (e.g., `.cache/`)
- [ ] Raise `ValueError` with helpful message if required config is missing
- [ ] Add logging configuration setup (log level, format)

**3. Word List Manager (`spelling_words/word_list.py`)**
- [ ] Create `WordListManager` class
- [ ] Implement `load_from_file(file_path: str) -> list[str]` method
  - [ ] Read file line by line
  - [ ] Strip whitespace from each line
  - [ ] Skip empty lines
  - [ ] Convert all words to lowercase for consistency
  - [ ] Raise `FileNotFoundError` if file doesn't exist
  - [ ] Raise `ValueError` if file is empty
- [ ] Implement `validate_word(word: str) -> bool` method
  - [ ] Check word is non-empty after stripping
  - [ ] Check word contains only alphabetic characters (allow hyphens/apostrophes)
  - [ ] Log warning for invalid words
- [ ] Implement `remove_duplicates(words: list[str]) -> list[str]`
  - [ ] Preserve order while removing duplicates
  - [ ] Log how many duplicates were removed
- [ ] Add comprehensive logging throughout

**4. Cache Manager (`spelling_words/cache.py`)**
- [ ] Create `CacheManager` class for disk-based caching
- [ ] Implement `__init__(cache_dir: str)` to set up cache directory
  - [ ] Create cache directory if it doesn't exist
  - [ ] Create subdirectories: `api_responses/`, `audio/`
- [ ] Implement `get_cache_key(url: str, params: dict) -> str`
  - [ ] Generate deterministic hash from URL and parameters
  - [ ] Use hashlib.sha256 for key generation
- [ ] Implement `get_cached_api_response(cache_key: str) -> dict | None`
  - [ ] Check if cache file exists in `api_responses/`
  - [ ] Read and return JSON data if exists
  - [ ] Return None if not cached
- [ ] Implement `cache_api_response(cache_key: str, response_data: dict, status_code: int)`
  - [ ] Only cache 2xx responses
  - [ ] Store response data as JSON with metadata (timestamp, status code)
  - [ ] Handle write errors gracefully (log but don't fail)
- [ ] Implement `get_cached_audio(filename: str) -> bytes | None`
  - [ ] Check if audio file exists in `audio/` directory
  - [ ] Return file contents as bytes if exists
- [ ] Implement `cache_audio(filename: str, audio_data: bytes)`
  - [ ] Write audio bytes to `audio/` directory
  - [ ] Handle write errors gracefully

**5. Dictionary API Client (`spelling_words/dictionary_client.py`)**
- [ ] Create `MerriamWebsterClient` class
- [ ] Implement `__init__(api_key: str, cache_manager: CacheManager)`
  - [ ] Validate API key is non-empty
  - [ ] Set base URL for Elementary Dictionary API
  - [ ] Store cache_manager reference
- [ ] Implement `get_word_data(word: str) -> dict | None`
  - [ ] Check cache first using cache_manager
  - [ ] If cached, return cached response
  - [ ] Build API URL: `https://dictionaryapi.com/api/v3/references/sd/json/{word}`
  - [ ] Make GET request with API key parameter
  - [ ] Set timeout to 10 seconds
  - [ ] Handle `requests.Timeout` with retry logic (max 3 attempts, exponential backoff)
  - [ ] Handle `requests.HTTPError` appropriately
  - [ ] Cache 2xx responses using cache_manager
  - [ ] Return parsed JSON response
  - [ ] Return None if word not found (check for "suggestion" response)
  - [ ] Log all API calls and results
- [ ] Implement `extract_definition(word_data: dict) -> str`
  - [ ] Parse JSON response structure to find first definition
  - [ ] Handle missing/malformed data gracefully
  - [ ] Return simplified definition text suitable for flashcard
  - [ ] Raise `ValueError` if no definition found
- [ ] Implement `extract_audio_urls(word_data: dict) -> list[str]`
  - [ ] Parse JSON to find audio file references
  - [ ] Build full audio URLs from file references
  - [ ] Handle subdirectory logic (bix, gg, number prefixes)
  - [ ] Return list of audio URLs (may be empty if no audio)
  - [ ] Log if no audio found for word

**6. Audio Downloader (`spelling_words/audio_downloader.py`)**
- [ ] Create `AudioDownloader` class
- [ ] Implement `__init__(cache_manager: CacheManager)`
  - [ ] Store cache_manager reference
- [ ] Implement `download_audio(url: str, word: str) -> bytes | None`
  - [ ] Generate cache filename from word and URL
  - [ ] Check cache first using cache_manager
  - [ ] If cached, return cached audio
  - [ ] Make GET request with timeout
  - [ ] Handle `requests.Timeout` with retry (max 3 attempts)
  - [ ] Validate response is audio (check Content-Type header)
  - [ ] Cache downloaded audio using cache_manager
  - [ ] Return audio bytes
  - [ ] Return None if download fails after retries
  - [ ] Log all download attempts and results
- [ ] Implement `download_first_pronunciation(urls: list[str], word: str) -> bytes | None`
  - [ ] For MVP, just download first URL from list
  - [ ] Use `download_audio()` method
  - [ ] Return None if urls list is empty
  - [ ] Log if multiple pronunciations exist (note for Phase 2)

**7. Audio Processor (`spelling_words/audio_processor.py`)**
- [ ] Create `AudioProcessor` class
- [ ] Implement `validate_audio(audio_bytes: bytes) -> bool`
  - [ ] Try to load audio using pydub
  - [ ] Catch `pydub.exceptions.CouldntDecodeError`
  - [ ] Return True if valid, False otherwise
- [ ] Implement `convert_to_mp3(audio_bytes: bytes, output_filename: str) -> bytes`
  - [ ] Load audio using pydub `AudioSegment`
  - [ ] Export as MP3 with 128k bitrate
  - [ ] Return MP3 bytes
  - [ ] Raise specific exception if conversion fails
  - [ ] Log conversion details
- [ ] Implement `generate_audio_filename(word: str) -> str`
  - [ ] Create sanitized filename from word
  - [ ] Add .mp3 extension
  - [ ] Ensure filename is unique (add counter if needed)
  - [ ] Return filename only (not full path)

**8. APKG Manager (`spelling_words/apkg_manager.py`)**
- [ ] Create `APKGManager` class
- [ ] Implement `__init__(output_path: str)`
  - [ ] Store output path for final APKG
  - [ ] Initialize empty media dict
  - [ ] Initialize empty notes list
- [ ] Implement `create_note(word: str, definition: str, audio_filename: str) -> dict`
  - [ ] Generate note ID: `int(time.time() * 1000)`
  - [ ] Generate GUID: random 10-character alphanumeric string
  - [ ] Set mid (model ID) to 1 (basic Anki model)
  - [ ] Format fields: `f"[sound:{audio_filename}]\x1fDefinition: {definition}\x1f{word.lower()}"`
  - [ ] Set sfld to first field (for sorting)
  - [ ] Calculate checksum using `sha1` of first field
  - [ ] Return note dict with all required fields
- [ ] Implement `add_note(note: dict)`
  - [ ] Add note to internal notes list
  - [ ] Log note creation
- [ ] Implement `add_media_file(filename: str, audio_data: bytes)`
  - [ ] Add to media dict with next available index
  - [ ] Store audio data for later compression
  - [ ] Log media file addition
- [ ] Implement `create_collection_db() -> bytes`
  - [ ] Create in-memory SQLite database
  - [ ] Create `notes` table with proper schema (id, guid, mid, mod, usn, tags, flds, sfld, csum, flags, data)
  - [ ] Create `cards` table with basic schema
  - [ ] Insert all notes into notes table using parameterized queries
  - [ ] Create corresponding cards for each note
  - [ ] Commit and get database as bytes
  - [ ] Return uncompressed DB bytes
- [ ] Implement `build_apkg()`
  - [ ] Create collection database
  - [ ] Compress database with Zstandard
  - [ ] Create ZIP file at output_path
  - [ ] Add compressed database as `collection.anki21b`
  - [ ] Create media JSON mapping (numeric keys to filenames)
  - [ ] Add media JSON as `media` file in ZIP
  - [ ] Compress and add each audio file as numbered file (0, 1, 2, ...)
  - [ ] Add empty `collection.anki2` for backwards compatibility
  - [ ] Close ZIP file
  - [ ] Log APKG creation success
  - [ ] Return output path

**9. Command-Line Interface (`spelling_words/cli.py`)**
- [ ] Create main CLI function using argparse or click
- [ ] Add argument: `--words` or `-w` for word list file path (required)
- [ ] Add argument: `--output` or `-o` for output APKG path (optional, default: `output.apkg`)
- [ ] Add argument: `--verbose` or `-v` for debug logging
- [ ] Implement main workflow:
  - [ ] Load configuration (API keys, etc.)
  - [ ] Initialize all components (cache, API client, downloaders, etc.)
  - [ ] Load word list
  - [ ] Remove duplicates
  - [ ] For each word:
    - [ ] Fetch word data from API
    - [ ] Extract definition
    - [ ] Extract audio URLs
    - [ ] Download first pronunciation
    - [ ] Validate and convert audio
    - [ ] Generate audio filename
    - [ ] Create note
    - [ ] Add note and media to APKG manager
    - [ ] Handle errors gracefully (log and skip word on failure)
  - [ ] Build final APKG file
  - [ ] Print summary (words processed, words skipped, output path)
- [ ] Add error handling for missing .env file
- [ ] Add progress indication (e.g., "Processing word 23/100...")

**10. Package Structure and Entry Point**
- [ ] Create `spelling_words/__init__.py` with version info
- [ ] Add `__main__.py` for `python -m spelling_words` support
- [ ] Configure `pyproject.toml` with CLI entry point
- [ ] Add package metadata (name, version, description, author)

**11. Testing and Validation**
- [ ] Create test word list with 5-10 common words (e.g., `tests/fixtures/test_words.txt`)
- [ ] Manual test: Run CLI with test word list
- [ ] Manual test: Verify APKG file is created
- [ ] Manual test: Load APKG in AnkiDroid
- [ ] Manual test: Verify cards display correctly (audio plays, definition shows)
- [ ] Manual test: Run again with same word list to verify caching works
- [ ] Manual test: Run with 100+ word list to verify scalability
- [ ] Check cache directory contains expected files
- [ ] Verify no API keys in git history

**12. Documentation**
- [ ] Update README.md with:
  - [ ] Project description
  - [ ] Installation instructions (uv setup, ffmpeg)
  - [ ] API key setup (.env file)
  - [ ] Basic usage examples
  - [ ] Example word list format
- [ ] Add inline code comments for complex logic
- [ ] Ensure all functions have docstrings

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
5. **Graceful degradation** (fallback APIs, skip problematic words)

## Testing Strategy

**Phase 1 (MVP)**:
- Manual testing with small word lists (5-20 words)
- Verify APKG loads in AnkiDroid

**Phase 2+**:
- Unit tests for each component
- Integration tests for full workflow
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
