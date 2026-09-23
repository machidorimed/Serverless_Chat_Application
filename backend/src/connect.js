const { CognitoJwtVerifier } = require("aws-jwt-verify");
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand } = require("@aws-sdk/lib-dynamodb");

const ddbClient = new DynamoDBClient({});
const ddb = DynamoDBDocumentClient.from(ddbClient);

const verifier = CognitoJwtVerifier.create({
  userPoolId: process.env.USER_POOL_ID,
  tokenUse: "id",
  clientId: process.env.USER_POOL_CLIENT_ID,
});

// API Gateway WebSocketの1接続あたりの最大生存時間(AWS固定上限)は2時間。
// $disconnectが呼ばれない異常切断に備え、それより長い猶予でTTLを設定する。
const CONNECTION_TTL_SECONDS = 60 * 60 * 3; // 3時間

// WebSocketのハンドシェイクではカスタムヘッダーを付けられないブラウザ実装があるため、
// IDトークンはクエリ文字列(?token=...)で受け取り、ここでCognitoのJWKSを用いて検証する。
//
// 注意: $connectの処理中は、API Gateway側でこの接続がまだ「確立済み」として
// 扱われないため、ここから PostToConnection でこの接続自身にデータを送ることはできない
// (履歴の配信は getHistory.js が別ルートとして行う)。
exports.handler = async (event) => {
  const connectionId = event.requestContext.connectionId;
  const token = event.queryStringParameters && event.queryStringParameters.token;

  if (!token) {
    console.error("Missing token in connect request", { connectionId });
    return { statusCode: 401, body: "Unauthorized: missing token" };
  }

  let payload;
  try {
    payload = await verifier.verify(token);
  } catch (err) {
    console.error("JWT verification failed", { connectionId, error: err.message });
    return { statusCode: 401, body: "Unauthorized: invalid token" };
  }

  const username =
    payload["nickname"] || payload["email"] || payload["cognito:username"] || payload.sub;

  await ddb.send(
    new PutCommand({
      TableName: process.env.CONNECTIONS_TABLE,
      Item: {
        connectionId,
        userId: payload.sub,
        username,
        connectedAt: new Date().toISOString(),
        ttl: Math.floor(Date.now() / 1000) + CONNECTION_TTL_SECONDS,
      },
    })
  );

  return { statusCode: 200, body: "Connected" };
};
