import { FormEvent, useState } from "react";

type Props = {
  onSignUp: (email: string, password: string) => Promise<void>;
  onConfirmSignUp: (email: string, code: string) => Promise<void>;
  onSignIn: (email: string, password: string) => Promise<void>;
};

type Mode = "signIn" | "signUp" | "confirm";

function errorMessage(err: unknown): string {
  return err instanceof Error ? err.message : String(err);
}

export function AuthForms({ onSignUp, onConfirmSignUp, onSignIn }: Props) {
  const [mode, setMode] = useState<Mode>("signIn");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const handleSignUp = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      await onSignUp(email, password);
      setMode("confirm");
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const handleConfirm = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      await onConfirmSignUp(email, code);
      // 確認コードの検証に成功したら、そのままサインインさせて
      // ニックネーム設定画面(App.tsx側)へ自然に遷移させる。
      await onSignIn(email, password);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const handleSignIn = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      await onSignIn(email, password);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="auth-forms">
      <img src="/images/logo.png" alt="Bird Bath" className="app-logo" />

      {mode === "signIn" && (
        <form onSubmit={handleSignIn}>
          <h2 className="signin-title">Sign in</h2>
          <input
            type="email"
            placeholder="メールアドレス"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
          <input
            type="password"
            placeholder="パスワード"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
          <button type="submit" disabled={busy}>
            サインイン
          </button>
          <p>
            アカウントがない場合は{" "}
            <button type="button" onClick={() => setMode("signUp")}>
              新規登録
            </button>
          </p>
        </form>
      )}

      {mode === "signUp" && (
        <form onSubmit={handleSignUp}>
          <h2>新規登録</h2>
          <input
            type="email"
            placeholder="メールアドレス"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
          <input
            type="password"
            placeholder="パスワード(8文字以上、大文字・数字を含む)"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
          <button type="submit" disabled={busy}>
            登録
          </button>
          <p>
            <button type="button" onClick={() => setMode("signIn")}>
              サインインに戻る
            </button>
          </p>
        </form>
      )}

      {mode === "confirm" && (
        <form onSubmit={handleConfirm}>
          <h2>確認コード入力</h2>
          <p>{email} 宛に届いた確認コードを入力してください。</p>
          <input
            type="text"
            placeholder="確認コード"
            value={code}
            onChange={(e) => setCode(e.target.value)}
            required
          />
          <button type="submit" disabled={busy}>
            確認
          </button>
        </form>
      )}

      {error && <p className="error">{error}</p>}
    </div>
  );
}
