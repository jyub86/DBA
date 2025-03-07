import { serve } from "https://deno.land/std@0.114.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const YOUTUBE_API_KEY = Deno.env.get("YOUTUBE_API_KEY");
const CHANNEL_ID = "UCk4rCQhC6Ab-hPNx_-2-CAQ";
const USER_ID = "aaa3a5de-67d1-4e47-80dd-f972407681af"; // 부평동부교회

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY, {
    db: {
        schema: 'public'
    },
    auth: {
        autoRefreshToken: false,
        persistSession: false,
        detectSessionInUrl: false
    }
});

// YouTube API를 통해 최신 영상 가져오기
async function getLatestVideos(maxResults = 50) {
    try {
        const channelResponse = await fetch(
            `https://www.googleapis.com/youtube/v3/channels?part=contentDetails&id=${CHANNEL_ID}&key=${YOUTUBE_API_KEY}`
        );
        const channelData = await channelResponse.json();

        if (!channelData.items?.[0]) {
            throw new Error('채널을 찾을 수 없습니다');
        }

        const uploadsPlaylistId = channelData.items[0].contentDetails.relatedPlaylists.uploads;

        // 2. uploads 재생목록에서 최신 영상들 가져오기
        const videosResponse = await fetch(
         `https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&maxResults=${maxResults}&playlistId=${uploadsPlaylistId}&key=${YOUTUBE_API_KEY}`
        );
        const videosData = await videosResponse.json();

        // 3. 필요한 정보만 추출
        return videosData.items.map(item => ({
            videoId: item.snippet.resourceId.videoId,
            title: item.snippet.title,
            publishedAt: item.snippet.publishedAt,
            url: `https://www.youtube.com/watch?v=${item.snippet.resourceId.videoId}`
        }));

    } catch (error) {
         console.error('영상 가져오기 실패:', error);
        throw error;
    }
}

const getCategoryID = {
    "설교": "4",
    "찬양": "5",
    "예배실황": "6",
    "목수교실": "8",
}

// Supabase에 새로운 영상 추가
async function uploadNewVideos() {
    try {
        const videos = await getLatestVideos(10);
        const results = {
            uploaded: 0,
            skipped: 0,
            errors: 0
        };

        for (const video of videos) {
            // 비디오 카테고리 확인
            let category = '';
            if (video.title.includes('주일오전예배 "') || video.title.includes('주일오후예배 "') || video.title.includes('금요기도회 "')) {
                category = "설교";
            } else if (video.title.includes('예배 찬양')) {
                category = "찬양";
            } else if (video.title.includes('주일오전예배 2부') || video.title.includes('주일오후예배') || video.title.includes('금요기도회')) {
                category = "예배실황";
            } else if (video.title.includes('목수교실')) {
                category = "목수교실";
            }

            if (!category) {
                console.log(`카테고리 확인 실패: ${video.title}`);
                results.skipped++;
                continue;
            }

            const categoryID = getCategoryID[category];

            // 1. 동일한 제목의 게시물이 있는지 확인
            const { data: existingPosts } = await supabase
            .from('posts')
            .select('id')
            .eq('title', video.title)
            .single();

            // 2. 존재하지 않는 경우에만 새로 추가
            if (!existingPosts) {
                console.log(`새로운 게시물 추가: ${video.title}, category: ${categoryID}, media_urls: ${video.url}`);
                const { error } = await supabase
                    .from('posts')
                    .insert([
                    {
                        title: video.title,
                        category_id: categoryID,
                        media_urls: [video.url],
                        active: true,
                        user_id: USER_ID
                    }
                    ]);
    
                if (error) {
                    console.error(`업로드 실패: ${video.title}`, error);
                    results.errors++;
                } else {
                    console.log(`업로드 성공: ${video.title}`);
                    results.uploaded++;
                }
            } else {
                console.log(`스킵됨 (이미 존재): ${video.title}`);
                results.skipped++;
            }
        }

        return results;
    } catch (error) {
        console.error('Error in uploadNewVideos:', error);
        throw error;
    }
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', {
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST',
                'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
            }
        });
    }

    try {
        const results = await uploadNewVideos();
        return new Response(
            JSON.stringify({
                success: true,
                message: `처리 완료: ${results.uploaded}개 업로드, ${results.skipped}개 스킵, ${results.errors}개 에러`,
                results
            }),
            {
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                }
            }
        );
    } catch (error) {
        return new Response(
            JSON.stringify({ error: error.message }),
            {
                status: 400,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                }
            }
        );
    }
});