const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
  DynamoDBDocumentClient,
  PutCommand,
  ScanCommand,
  DeleteCommand,
  GetCommand,
} = require("@aws-sdk/lib-dynamodb");
const {
  ApiGatewayManagementApiClient,
  PostToConnectionCommand,
} = require("@aws-sdk/client-apigatewaymanagementapi");
const { randomUUID } = require("crypto");

const ddbClient = new DynamoDBClient({});
const ddb = DynamoDBDocumentClient.from(ddbClient);

// 現状は単一の全体チャットルームのみ。複数ルーム化する場合はクライアントからroomIdを受け取る形に拡張する。
const ROOM_ID = "global";
const MAX_MESSAGE_LENGTH = 2000;

exports.handler = async (event) => {
  const connectionId = event.requestContext.connectionId;
  const domain = event.requestContext.domainName;
  const stage = event.requestContext.stage;

  const apiGwClient = new ApiGatewayManagementApiClient({
    endpoint: `https://${domain}/${stage}`,
  });

  let body;
  try {
    body = JSON.parse(event.body || "{}");
  } catch (err) {
    return { statusCode: 400, body: "Invalid JSON" };
  }

  const messageText = (body.message || "").toString().trim();
  if (!messageText) {
    return { statusCode: 400, body: "Message is required" };
  }
  if (messageText.length > MAX_MESSAGE_LENGTH) {
    return { statusCode: 400, body: "Message too long" };
  }

  const senderResult = await ddb.send(
    new GetCommand({
      TableName: process.env.CONNECTIONS_TABLE,
      Key: { connectionId },
    })
  );
  const sender = senderResult.Item;
  if (!sender) {
    return { statusCode: 401, body: "Unknown connection" };
  }

  const timestamp = new Date().toISOString();
  const messageId = randomUUID();

  await ddb.send(
    new PutCommand({
      TableName: process.env.MESSAGES_TABLE,
      Item: {
        roomId: ROOM_ID,
        sortKey: `${timestamp}#${messageId}`,
        messageId,
        userId: sender.userId,
        username: sender.username,
        message: messageText,
        createdAt: timestamp,
      },
    })
  );

  const connectionsResult = await ddb.send(
    new ScanCommand({
      TableName: process.env.CONNECTIONS_TABLE,
    })
  );

  const payload = Buffer.from(
    JSON.stringify({
      type: "message",
      messageId,
      userId: sender.userId,
      username: sender.username,
      message: messageText,
      createdAt: timestamp,
    })
  );

  const staleConnectionIds = [];

  await Promise.all(
    (connectionsResult.Items || []).map(async (conn) => {
      try {
        await apiGwClient.send(
          new PostToConnectionCommand({
            ConnectionId: conn.connectionId,
            Data: payload,
          })
        );
      } catch (err) {
        // 410 Gone: クライアントが既に切断済みなのにConnectionsテーブルに残っている場合。
        // $disconnectルートが呼ばれない異常切断(ネットワーク断など)で発生しうるため、ここで掃除する。
        if (err.name === "GoneException" || err.$metadata?.httpStatusCode === 410) {
          staleConnectionIds.push(conn.connectionId);
        } else {
          console.error("Failed to post to connection", {
            connectionId: conn.connectionId,
            error: err.message,
          });
        }
      }
    })
  );

  await Promise.all(
    staleConnectionIds.map((staleId) =>
      ddb.send(
        new DeleteCommand({
          TableName: process.env.CONNECTIONS_TABLE,
          Key: { connectionId: staleId },
        })
      )
    )
  );

  return { statusCode: 200, body: "Message sent" };
};
