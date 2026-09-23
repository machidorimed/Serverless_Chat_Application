import { useCallback, useEffect, useRef, useState } from "react";

export type ChatMessage = {
  messageId: string;
  userId: string;
  username: string;
  message: string;
  createdAt: string;
};

export type ConnectionStatus = "connecting" | "open" | "closed";

export function useChatSocket(idToken: string | null) {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [status, setStatus] = useState<ConnectionStatus>("connecting");
  const wsRef = useRef<WebSocket | null>(null);

  useEffect(() => {
    if (!idToken) {
      return;
    }

    const url = `${import.meta.env.VITE_WEBSOCKET_URL}?token=${encodeURIComponent(idToken)}`;
    const ws = new WebSocket(url);
    wsRef.current = ws;
    setStatus("connecting");

    ws.onopen = () => {
      setStatus("open");
      // 接続が確立してから履歴をリクエストする($connect処理中はまだ
      // PostToConnectionが使えないため、サーバー側からの自動送信ではなく
      // クライアント起点でリクエストする)
      ws.send(JSON.stringify({ action: "getHistory" }));
    };
    ws.onclose = () => setStatus("closed");
    ws.onerror = () => setStatus("closed");
    ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        if (data.type === "message") {
          setMessages((prev) => [...prev, data as ChatMessage]);
        } else if (data.type === "history") {
          // 接続直後に届く、直近の履歴(古い順)。初期表示としてまとめて差し替える。
          setMessages(data.messages as ChatMessage[]);
        }
      } catch {
        // 不正な形式のメッセージは無視する
      }
    };

    return () => {
      ws.close();
      wsRef.current = null;
    };
  }, [idToken]);

  const sendMessage = useCallback((text: string) => {
    const ws = wsRef.current;
    if (!ws || ws.readyState !== WebSocket.OPEN) {
      return false;
    }
    ws.send(JSON.stringify({ action: "sendMessage", message: text }));
    return true;
  }, []);

  return { messages, status, sendMessage };
}
