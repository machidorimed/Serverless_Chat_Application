import { useAuth } from "./auth/useAuth";
import { AuthForms } from "./auth/AuthForms";
import { SetNickname } from "./auth/SetNickname";
import { ChatRoom } from "./chat/ChatRoom";

export default function App() {
  const { user, loading, signUp, confirmSignUp, signIn, signOut, setNickname } = useAuth();

  if (loading) {
    return <p>読み込み中...</p>;
  }

  if (!user) {
    return <AuthForms onSignUp={signUp} onConfirmSignUp={confirmSignUp} onSignIn={signIn} />;
  }

  if (!user.nickname) {
    return <SetNickname onSubmit={setNickname} />;
  }

  return (
    <ChatRoom idToken={user.idToken} username={user.nickname} userId={user.userId} onSignOut={signOut} />
  );
}
