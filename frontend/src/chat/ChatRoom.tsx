import { FormEvent, useEffect, useRef, useState } from "react";
import { useChatSocket } from "./useChatSocket";

type Props = {
  idToken: string;
  username: string;
  userId: string;
  onSignOut: () => void;
};

export function ChatRoom({ idToken, username, userId, onSignOut }: Props) {
  const { messages, status, sendMessage } = useChatSocket(idToken);
  const [text, setText] = useState("");
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const prevCountRef = useRef(0);

  useEffect(() => {
    audioRef.current = new Audio("/sounds/notify.mp3");
  }, []);

  useEffect(() => {
    const prevCount = prevCountRef.current;
    prevCountRef.current = messages.length;

    // 接続直後の履歴一括読み込みでは鳴らさず、新着が1件ずつ届いた時だけ鳴らす
    if (messages.length - prevCount !== 1) {
      return;
    }

    const latest = messages[messages.length - 1];
    if (latest && latest.userId !== userId) {
      audioRef.current?.play().catch(() => {
        // ブラウザの自動再生制限で失敗しても無視する
      });
    }
  }, [messages, userId]);

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    const trimmed = text.trim();
    if (!trimmed) {
      return;
    }
    if (sendMessage(trimmed)) {
      setText("");
    }
  };

  return (
    <div className="chat-room">
      <header>
        <span>ログイン中: {username}</span>
        <span className={`status status-${status}`}>{status}</span>
        <button onClick={onSignOut}>サインアウト</button>
      </header>

      <ul className="message-list">
        {messages.map((m) => (
          <li key={m.messageId} className={m.userId === userId ? "mine" : ""}>
            <strong>{m.username}</strong>
            <span>{m.message}</span>
            <time>{new Date(m.createdAt).toLocaleTimeString()}</time>
          </li>
        ))}
      </ul>

      <form onSubmit={handleSubmit}>
        <input
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="メッセージを入力"
          disabled={status !== "open"}
        />
        <button type="submit" disabled={status !== "open"}>
          送信
        </button>
      </form>

      {status === "closed" && (
        <p className="warning">接続が切れました。再読み込みして再度サインインしてください。</p>
      )}
    </div>
  );
}
