import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 요청 본문에서 사용자 ID 추출
    const { user_id } = await req.json()

    if (!user_id) {
      throw new Error('user_id is required')
    }

    // Supabase 클라이언트 생성 (서비스 롤 키 사용)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // 1. custom_users 테이블에서 사용자 데이터 삭제
    const { error: customUserError } = await supabaseAdmin
      .from('custom_users')
      .delete()
      .eq('auth_id', user_id)

    if (customUserError) {
      throw customUserError
    }

    // 2. auth.users에서 사용자 삭제
    const { error: authError } = await supabaseAdmin.auth.admin.deleteUser(
      user_id
    )

    if (authError) {
      throw authError
    }

    return new Response(
      JSON.stringify({ message: 'User deleted successfully' }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
}) 