import { serve } from "https://deno.land/std@0.114.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import serviceAccount from './service-account.json' assert { type: "json" };

// 서비스 계정 유효성 검사
if (!serviceAccount.project_id || !serviceAccount.private_key || !serviceAccount.client_email) {
  throw new Error('Firebase service account configuration is missing or invalid');
}

// FCM 관련 상수
const FCM_URL = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;
const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

// JWT 토큰 생성 함수
async function generateAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const jwt = {
    iss: serviceAccount.client_email,
    scope: SCOPE,
    aud: GOOGLE_TOKEN_URL,
    exp: now + 3600,
    iat: now,
  };

  const encoder = new TextEncoder();
  const header = encoder.encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const payload = encoder.encode(JSON.stringify(jwt));

  const headerBase64 = btoa(String.fromCharCode(...header)).replace(/=/g, '');
  const payloadBase64 = btoa(String.fromCharCode(...payload)).replace(/=/g, '');

  const signatureInput = `${headerBase64}.${payloadBase64}`;
  
  const key = await crypto.subtle.importKey(
    'pkcs8',
    base64ToArrayBuffer(serviceAccount.private_key.replace(/-----[^-]*-----/g, '').replace(/\\n/g, '').replace(/\n/g, '')),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const signature = await crypto.subtle.sign(
    { name: 'RSASSA-PKCS1-v1_5' },
    key,
    encoder.encode(signatureInput)
  );

  const signatureBase64 = btoa(String.fromCharCode(...new Uint8Array(signature))).replace(/=/g, '');
  const signedJwt = `${headerBase64}.${payloadBase64}.${signatureBase64}`;

  const tokenResponse = await fetch(GOOGLE_TOKEN_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: signedJwt,
    }),
  });

  const { access_token } = await tokenResponse.json();
  return access_token;
}

// Base64 디코딩 유틸리티 함수
function base64ToArrayBuffer(base64: string): ArrayBuffer {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

interface MessageRecord {
  id: number;
  sender_id: string;
  receiver_id?: string;
  group_id?: string;
  title?: string;
  message: string;
  message_type: 'global' | 'personal' | 'group';
  created_at: string;
}

// FCM 메시지 전송 함수
async function sendFCMMessage(token: string, message: any): Promise<any> {
  const accessToken = await generateAccessToken();
  
  const requestBody = {
    message: {
      token,
      notification: {
        title: message.notification.title,
        body: message.notification.body,
      },
      data: Object.fromEntries(
        Object.entries(message.data || {}).map(([key, value]) => [key, String(value)])
      ),
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
          notificationPriority: "PRIORITY_MAX",
          defaultSound: true,
          defaultVibrateTimings: true,
          visibility: "PUBLIC",
          clickAction: "FLUTTER_NOTIFICATION_CLICK"
        }
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert"
        },
        payload: {
          aps: {
            alert: {
              title: message.notification.title,
              body: message.notification.body,
            },
            sound: "default",
            badge: 1,
            "content-available": 1,
            "mutable-content": 1,
            priority: 10
          }
        }
      }
    }
  };
  
  const response = await fetch(FCM_URL, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(requestBody),
  });

  const responseData = await response.json();
  
  if (!response.ok) {
    console.error('FCM 전송 실패:', responseData.error?.message || responseData);
    throw new Error(`FCM 전송 실패: ${JSON.stringify(responseData)}`);
  }

  return responseData;
}

// 청크 단위로 메시지를 전송하는 함수
async function sendMessagesInChunks(tokens: string[], message: any, chunkSize: number = 50) {
  const results = {
    successCount: 0,
    failureCount: 0,
    responses: [] as any[]
  };

  for (let i = 0; i < tokens.length; i += chunkSize) {
    const chunk = tokens.slice(i, i + chunkSize);
    const promises = chunk.map(token => 
      sendFCMMessage(token, message)
        .then(response => ({ success: true, response }))
        .catch(error => ({ success: false, error }))
    );

    const chunkResults = await Promise.allSettled(promises);
    const successfulResults = chunkResults.filter(
      result => result.status === 'fulfilled' && result.value.success
    );
    
    results.successCount += successfulResults.length;
    results.failureCount += chunkResults.length - successfulResults.length;
    results.responses.push(...chunkResults.map(result => 
      result.status === 'fulfilled' ? result.value : {
        success: false,
        error: { message: result.reason?.message || 'Unknown error' }
      }
    ));

    if (i + chunkSize < tokens.length) {
      await new Promise(resolve => setTimeout(resolve, 500));
    }
  }

  return results;
}

serve(async (req) => {
  try {
    if (req.method === 'OPTIONS') {
      return new Response('ok', {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        }
      });
    }

    if (req.method !== 'POST') {
      throw new Error('Method not allowed');
    }

    const { record } = await req.json() as { record: MessageRecord };
    if (!record || !['global', 'personal', 'group'].includes(record.message_type)) {
      throw new Error('Invalid request body');
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // 발신자 정보 조회
    const { data: senderData } = await supabase
      .from('custom_users')
      .select('name')
      .eq('auth_id', record.sender_id)
      .single();

    const senderName = senderData?.name || '알 수 없음';
    let fcmTokens: string[] = [];
    let userQuery = supabase.from("user_tokens").select("fcm_token");

    // 메시지 타입에 따른 토큰 조회
    switch (record.message_type) {
      case "global":
        const { data: allTokens } = await userQuery;
        fcmTokens = allTokens?.map(row => row.fcm_token) || [];
        break;

      case "personal":
        const { data: userTokens } = await userQuery.eq("user_id", record.receiver_id);
        fcmTokens = userTokens?.map(row => row.fcm_token) || [];
        break;

      case "group":
        if (!record.group_id) throw new Error("Group ID is required for group messages");
        
        const { data: groupData } = await supabase
          .from('groups')
          .select('name')
          .eq('id', record.group_id)
          .single();
        
        const { data: users } = await supabase
          .from("user_groups")
          .select("user_id")
          .eq("group_id", record.group_id);
        
        const userIds = users?.map(row => row.user_id) || [];
        const { data: groupTokens } = await userQuery.in("user_id", userIds);
        fcmTokens = groupTokens?.map(row => row.fcm_token) || [];
        break;
    }

    if (fcmTokens.length === 0) {
      return new Response(
        JSON.stringify({ message: "No recipients found" }), 
        { status: 404, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // 메시지 구성
    const message = {
      notification: {
        title: record.message_type === 'global' ? `${record.title || ''}` :
               record.message_type === 'personal' ? `${senderName}님의 메시지` :
               `${senderName}님의 그룹 메시지`,
        body: record.message,
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        type: record.message_type,
        messageId: record.id.toString(),
        senderId: record.sender_id,
        senderName,
        title: record.title || '',
        groupId: record.group_id || '',
        timestamp: record.created_at,
        screen: "notification_screen",
        route: "/notification"
      },
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
          notificationPriority: "PRIORITY_MAX",
          defaultSound: true,
          defaultVibrateTimings: true,
          visibility: "PUBLIC",
          clickAction: "FLUTTER_NOTIFICATION_CLICK"
        }
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert"
        },
        payload: {
          aps: {
            alert: {
              title: record.message_type === 'global' ? `${record.title || ''}` :
                     record.message_type === 'personal' ? `${senderName}님의 메시지` :
                     `${senderName}님의 그룹 메시지`,
              body: record.message,
            },
            sound: "default",
            badge: 1,
            "content-available": 1,
            "mutable-content": 1,
            priority: 10
          }
        }
      }
    };

    const results = await sendMessagesInChunks(fcmTokens, message);

    console.log(`알림 전송 완료: 성공 ${results.successCount}건, 실패 ${results.failureCount}건, 총 ${fcmTokens.length}건`);

    return new Response(
      JSON.stringify({
        success: true,
        successCount: results.successCount,
        failureCount: results.failureCount,
        totalProcessed: fcmTokens.length
      }),
      { 
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      }
    );

  } catch (error) {
    console.error('알림 전송 중 오류 발생:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return new Response(
      JSON.stringify({ error: errorMessage }),
      { 
        status: errorMessage === 'Method not allowed' ? 405 : 400,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      }
    );
  }
});
