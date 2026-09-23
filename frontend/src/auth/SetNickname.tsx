import { FormEvent, useState } from "react";

type Props = {
  onSubmit: (nickname: string) => Promise<void>;
};

export function SetNickname({ onSubmit }: Props) {
  const [nickname, setNickname] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    const trimmed = nickname.trim();
    if (!trimmed) {
      return;
    }
    setError(null);
    setBusy(true);
    try {
      await onSubmit(trimmed);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="auth-forms">
      <img src="/images/logo.png" alt="Bird Bath" className="app-logo" />
      <form onSubmit={handleSubmit}>
        <h2>ニックネームを決めてください</h2>
        <input
          type="text"
          placeholder="ニックネーム"
          value={nickname}
          onChange={(e) => setNickname(e.target.value)}
          maxLength={30}
          required
        />
        <button type="submit" disabled={busy}>
          決定
        </button>
      </form>
      {error && <p className="error">{error}</p>}
    </div>
  );
}
