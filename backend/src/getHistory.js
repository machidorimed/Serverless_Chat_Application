const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, QueryCommand } = require("@aws-sdk/lib-dynamodb");
const {
  ApiGatewayManagementApiClient,
  PostToConnectionCommand,
} = require("@aws-sdk/client-apigatewaymanagementapi");

const ddbClient = new DynamoDBClient({});
const ddb = DynamoDBDocumentClient.from(ddbClient);

// 現状は単一の全体チャットルームのみ。sendMessage.js/connect.jsと合わせる。
const ROOM_ID = "global";
const HISTORY_LIMIT = 10;

// クライアントが接続完了後(WebSocketのonopen後)に action:"getHistory" を送ってくる
// custom route。$connectの中では接続がまだ確立済み扱いにならず
// PostToConnectionが使えないため、履歴配信はこの別ルートで行う。
exports.handler = async (event) => {
  const connectionId = event.requestContext.connectionId;
  const domain = event.requestContext.domainName;
  const stage = event.requestContext.stage;

  const apiGwClient = new ApiGatewayManagementApiClient({
    endpoint: `https://${domain}/${stage}`,
  });

  const historyResult = await ddb.send(
    new QueryCommand({
      TableName: process.env.MESSAGES_TABLE,
      KeyConditionExpression: "roomId = :r",
      ExpressionAttributeValues: { ":r": ROOM_ID },
      ScanIndexForward: false, // 新しい順(sortKeyの降順)に取得
      Limit: HISTORY_LIMIT,
    })
  );

  const history = (historyResult.Items || [])
    .reverse() // 画面表示用に古い順へ並べ替え
    .map((item) => ({
      messageId: item.messageId,
      userId: item.userId,
      username: item.username,
      message: item.message,
      createdAt: item.createdAt,
    }));

  await apiGwClient.send(
    new PostToConnectionCommand({
      ConnectionId: connectionId,
      Data: Buffer.from(JSON.stringify({ type: "history", messages: history })),
    })
  );

  return { statusCode: 200, body: "History sent" };
};
