/* ===== 事前生成済み音声プレーヤー ===== */

const AUDIO_BASE_PATH = '../assets/audio/';

class AudioPlayer {
  constructor() {
    this._audio = null;
    this._abortController = null;
    this._playing = false;
  }

  get isPlaying() {
    return this._playing;
  }

  /** 単一音声ファイルを再生 */
  async playFile(url) {
    this.stop();
    this._abortController = new AbortController();
    this._playing = true;

    try {
      await this._playUrl(url, this._abortController.signal);
    } catch (e) {
      if (e.name !== 'AbortError' && e.message !== 'aborted') {
        throw e;
      }
    } finally {
      this._playing = false;
    }
  }

  /** 複数音声ファイルを順次再生 */
  async playSequence(urls) {
    this.stop();
    this._abortController = new AbortController();
    const signal = this._abortController.signal;
    this._playing = true;

    try {
      for (let i = 0; i < urls.length; i++) {
        if (signal.aborted) break;
        await this._playUrl(urls[i], signal);

        // 最後の音声以外は再生後に1秒（1000ms）のインターバルを入れる
        if (i < urls.length - 1 && !signal.aborted) {
          await new Promise(resolve => {
            const timeoutId = setTimeout(resolve, 1000);
            signal.addEventListener('abort', () => {
              clearTimeout(timeoutId);
              resolve();
            }, { once: true });
          });
        }
      }
    } catch (e) {
      if (e.name !== 'AbortError' && e.message !== 'aborted') {
        throw e;
      }
    } finally {
      this._playing = false;
    }
  }

  /** 再生停止 */
  stop() {
    if (this._abortController) {
      this._abortController.abort();
      this._abortController = null;
    }
    if (this._audio) {
      this._audio.pause();
      this._audio.currentTime = 0;
      this._audio = null;
    }
    this._playing = false;
  }

  /** URLを再生してPromiseを返す（内部用） */
  _playUrl(url, signal) {
    return new Promise((resolve, reject) => {
      const audio = new Audio(url);
      this._audio = audio;

      const onAbort = () => {
        audio.pause();
        resolve();
      };
      signal.addEventListener('abort', onAbort, { once: true });

      audio.onended = () => {
        signal.removeEventListener('abort', onAbort);
        this._audio = null;
        resolve();
      };

      audio.onerror = () => {
        signal.removeEventListener('abort', onAbort);
        this._audio = null;
        reject(new Error('音声ファイルが見つかりません: ' + url));
      };

      audio.play().catch((e) => {
        signal.removeEventListener('abort', onAbort);
        this._audio = null;
        reject(e);
      });
    });
  }
}

/** slugから音声ファイルパスを生成 */
function getArticleAudioPath(slug) {
  return AUDIO_BASE_PATH + slug + '/article.wav';
}

function getCommentAudioPath(slug, index) {
  return AUDIO_BASE_PATH + slug + '/comment-' + index + '.wav';
}

// グローバルインスタンス
const audioPlayer = new AudioPlayer();
