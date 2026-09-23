import { useCallback, useEffect, useState } from "react";
import {
  signUp,
  confirmSignUp,
  signIn,
  signOut,
  updateUserAttributes,
  fetchAuthSession,
  getCurrentUser,
} from "aws-amplify/auth";

export type AuthUser = {
  username: string;
  idToken: string;
  nickname?: string;
  userId: string;
};

export function useAuth() {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [loading, setLoading] = useState(true);

  const refreshSession = useCallback(async (options?: { forceRefresh?: boolean }) => {
    try {
      const { username } = await getCurrentUser();
      const session = await fetchAuthSession({ forceRefresh: options?.forceRefresh });
      const idTokenObj = session.tokens?.idToken;
      const idToken = idTokenObj?.toString();
      const nickname =
        typeof idTokenObj?.payload?.nickname === "string" ? idTokenObj.payload.nickname : undefined;
      // Cognitoが発行する不変の一意ID(sub)。ニックネームは重複しうるため、
      // 「自分の発言かどうか」の判定にはこちらを使う。
      const userId = typeof idTokenObj?.payload?.sub === "string" ? idTokenObj.payload.sub : undefined;
      setUser(idToken && userId ? { username, idToken, nickname, userId } : null);
    } catch {
      setUser(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refreshSession();
  }, [refreshSession]);

  const handleSignUp = useCallback(async (email: string, password: string) => {
    await signUp({
      username: email,
      password,
      options: { userAttributes: { email } },
    });
  }, []);

  const handleConfirmSignUp = useCallback(async (email: string, code: string) => {
    await confirmSignUp({ username: email, confirmationCode: code });
  }, []);

  const handleSignIn = useCallback(
    async (email: string, password: string) => {
      await signIn({ username: email, password });
      await refreshSession();
    },
    [refreshSession]
  );

  const handleSignOut = useCallback(async () => {
    await signOut();
    setUser(null);
  }, []);

  const handleSetNickname = useCallback(
    async (nickname: string) => {
      await updateUserAttributes({ userAttributes: { nickname } });
      // Cognito側の属性を更新しても、発行済みのIDトークンには反映されないため、
      // トークンを再発行させて新しいnicknameをクレームに含める。
      await refreshSession({ forceRefresh: true });
    },
    [refreshSession]
  );

  return {
    user,
    loading,
    signUp: handleSignUp,
    confirmSignUp: handleConfirmSignUp,
    signIn: handleSignIn,
    signOut: handleSignOut,
    setNickname: handleSetNickname,
  };
}
