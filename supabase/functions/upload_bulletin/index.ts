// SUPABASE EDGEFUNCTION이 아님
// 부평동부교회 홈페이지에서 PDF파일을 다운 받고, PDF를 이미지로 변환하고 좌우로 나누는 함수
const OUTPUT_DIR = "build/temp";
const CHURCH_WEBSITE_URL = "https://xn--9d0by7j11iba736zkqd.com/board/%EC%A3%BC%EB%B3%B4/1002/";

import { ensureDir } from "https://deno.land/std@0.191.0/fs/ensure_dir.ts";
import { join } from "https://deno.land/std@0.191.0/path/mod.ts";
import { serve } from "https://deno.land/std@0.114.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { load } from "https://deno.land/std@0.191.0/dotenv/mod.ts";

// .env 파일에서 환경 변수 로드
try {
  const env = await load();
  // 환경 변수를 Deno.env에 설정
  Object.entries(env).forEach(([key, value]) => {
    Deno.env.set(key, value);
  });
  console.log(".env 파일 로드 성공");
} catch (error) {
  console.warn(".env 파일 로드 실패:", error);
}

// Supabase 설정
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const USER_ID = "aaa3a5de-67d1-4e47-80dd-f972407681af"; // 부평동부교회
const CATEGORY_ID = 3; // 주보 카테고리 ID

console.log("Supabase URL:", SUPABASE_URL);
console.log("Supabase Key 설정됨:", SUPABASE_KEY ? "O" : "X");

if (!SUPABASE_URL || !SUPABASE_KEY) {
  console.error("오류: Supabase URL 또는 Service Role Key가 설정되지 않았습니다.");
  if (import.meta.main) {
    Deno.exit(1);
  }
}

// Supabase 클라이언트 생성
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

/**
 * 교회 웹사이트에서 최신 주보 PDF URL을 가져오는 함수
 * @returns PDF URL과 제목
 */
async function fetchLatestBulletinPdf(): Promise<{ pdfUrl: string; title: string }> {
  try {
    console.log(`교회 웹사이트에서 최신 주보 정보를 가져오는 중... (${CHURCH_WEBSITE_URL})`);
    
    // 웹사이트 HTML 가져오기
    const response = await fetch(CHURCH_WEBSITE_URL);
    if (!response.ok) {
      throw new Error(`웹사이트 접근 실패: ${response.status} ${response.statusText}`);
    }
    
    const html = await response.text();
    
    // 최신 주보 게시물 링크 찾기
    const latestPostRegex = /<a[^>]*href="([^"]*\/article\/교회소식\/[^"]*)"[^>]*>\s*(\d{4}년\s*\d{1,2}월\s*\d{1,2}일\s*교회소식)/i;
    const latestPostMatch = html.match(latestPostRegex);
    
    if (!latestPostMatch || !latestPostMatch[1]) {
      throw new Error("웹사이트에서 최신 주보 게시물을 찾을 수 없습니다.");
    }
    
    // 게시물 URL 추출 및 절대 경로로 변환
    let postUrl = latestPostMatch[1];
    // '#none' 제거
    postUrl = postUrl.replace(/#none$/, '');
    
    if (postUrl.startsWith('//')) {
      postUrl = 'https:' + postUrl;
    } else if (!postUrl.startsWith('http')) {
      // 도메인 추출
      const domainMatch = CHURCH_WEBSITE_URL.match(/^(https?:\/\/[^\/]+)/);
      const domain = domainMatch ? domainMatch[1] : 'https://xn--9d0by7j11iba736zkqd.com';
      postUrl = domain + (postUrl.startsWith('/') ? '' : '/') + postUrl;
    }
    
    console.log(`최신 주보 게시물 URL: ${postUrl}`);
    
    // 게시물 페이지 가져오기
    const postResponse = await fetch(postUrl);
    if (!postResponse.ok) {
      throw new Error(`게시물 페이지 접근 실패: ${postResponse.status} ${postResponse.statusText}`);
    }
    
    const postHtml = await postResponse.text();
    
    // 디버깅: HTML 일부 출력
    const htmlPreview = postHtml.substring(0, 1000) + "...";
    console.log("게시물 HTML 미리보기:", htmlPreview);
    
    // PDF 파일 링크 찾기 (다양한 패턴 시도)
    let pdfUrl = "";
    
    // 패턴 1: 일반적인 href 속성의 PDF 링크
    const pdfLinkRegex1 = /href="([^"]+\.pdf)"/i;
    const pdfLinkMatch1 = postHtml.match(pdfLinkRegex1);
    
    // 패턴 2: 첨부파일 영역에서 PDF 링크 찾기
    const pdfLinkRegex2 = /첨부파일[^<]*<[^>]*href="([^"]+\.pdf)/i;
    const pdfLinkMatch2 = postHtml.match(pdfLinkRegex2);
    
    // 패턴 3: 다운로드 링크 찾기
    const pdfLinkRegex3 = /download[^<]*<[^>]*href="([^"]+\.pdf)/i;
    const pdfLinkMatch3 = postHtml.match(pdfLinkRegex3);
    
    if (pdfLinkMatch1 && pdfLinkMatch1[1]) {
      pdfUrl = pdfLinkMatch1[1];
      console.log("패턴 1로 PDF 링크 찾음");
    } else if (pdfLinkMatch2 && pdfLinkMatch2[1]) {
      pdfUrl = pdfLinkMatch2[1];
      console.log("패턴 2로 PDF 링크 찾음");
    } else if (pdfLinkMatch3 && pdfLinkMatch3[1]) {
      pdfUrl = pdfLinkMatch3[1];
      console.log("패턴 3로 PDF 링크 찾음");
    } else {
      // 직접 URL 구성 시도
      // 게시물 URL에서 ID 추출
      const postIdMatch = postUrl.match(/\/(\d+)\/$/);
      if (postIdMatch && postIdMatch[1]) {
        const year = new Date().getFullYear();
        const month = (new Date().getMonth() + 1).toString().padStart(2, '0');
        const day = new Date().getDate().toString().padStart(2, '0');
        
        // 추정된 PDF 파일명 생성
        pdfUrl = `https://xn--9d0by7j11iba736zkqd.com/web/upload/NNEditor/20${year.toString().slice(-2)}/${month}/${year}년(61-11호) ${month}월 ${day}일.pdf`;
        console.log("패턴 매칭 실패, 추정된 PDF URL 사용");
      } else {
        throw new Error("게시물에서 PDF 링크를 찾을 수 없습니다.");
      }
    }
    
    // '#none' 제거
    pdfUrl = pdfUrl.replace(/#none$/, '');
    
    // PDF URL 절대 경로로 변환
    if (pdfUrl.startsWith('//')) {
      pdfUrl = 'https:' + pdfUrl;
    } else if (!pdfUrl.startsWith('http')) {
      // 도메인 추출
      const domainMatch = CHURCH_WEBSITE_URL.match(/^(https?:\/\/[^\/]+)/);
      const domain = domainMatch ? domainMatch[1] : 'https://xn--9d0by7j11iba736zkqd.com';
      pdfUrl = domain + (pdfUrl.startsWith('/') ? '' : '/') + pdfUrl;
    }
    
    // 제목 추출 (예: "2025년 3월 16일 교회소식")
    const titleText = latestPostMatch[2] || "";
    
    // 제목에서 날짜 부분 추출하여 YY/MM/DD 형식으로 변환
    let title = "";
    const dateRegex = /(\d{4})년\s*(\d{1,2})월\s*(\d{1,2})일/;
    const dateMatch = titleText.match(dateRegex);
    
    if (dateMatch) {
      const year = dateMatch[1].slice(-2); // 4자리 연도에서 뒤의 2자리만 사용
      const month = dateMatch[2].padStart(2, '0');
      const day = dateMatch[3].padStart(2, '0');
      title = `${year}/${month}/${day} 주보`;
    } else {
      // 날짜 형식이 맞지 않으면 현재 날짜 사용
      const now = new Date();
      const year = now.getFullYear().toString().slice(-2);
      const month = (now.getMonth() + 1).toString().padStart(2, '0');
      const day = now.getDate().toString().padStart(2, '0');
      title = `${year}/${month}/${day} 주보`;
    }
    
    console.log(`최신 주보 정보 찾음: ${title}`);
    console.log(`PDF URL: ${pdfUrl}`);
    
    return { pdfUrl, title };
  } catch (error) {
    console.error("주보 정보 가져오기 실패:", error);
    throw error;
  }
}

/**
 * PDF를 이미지로 변환하고 좌우로 나누는 함수
 * @param pdfPath PDF 파일 경로
 * @param outputDir 출력 디렉토리 경로
 * @param targetHeight 목표 이미지 높이 (기본값: 1080)
 * @returns 생성된 이미지 파일 경로 목록 (순서: 1_right, 2_left, 2_right, 1_left)
 */
async function pdfToSplitImages(pdfPath: string, outputDir: string, targetHeight = 1080): Promise<string[]> {
  try {
    // 출력 디렉토리 생성
    await ensureDir(outputDir);
    
    // 임시 디렉토리 생성
    const tempDir = join(outputDir, "temp");
    await ensureDir(tempDir);
    
    // pdftoppm을 사용하여 PDF를 이미지로 변환
    const dpi = 300; // 해상도 설정
    const pdftoppmCommand = new Deno.Command("pdftoppm", {
      args: [
        "-png",        // PNG 형식으로 출력
        "-r", String(dpi),  // 해상도 설정
        pdfPath,       // 입력 PDF 파일
        join(tempDir, "page")  // 출력 이미지 파일 접두사
      ]
    });
    
    const pdftoppmOutput = await pdftoppmCommand.output();
    if (!pdftoppmOutput.success) {
      const errorMessage = new TextDecoder().decode(pdftoppmOutput.stderr);
      throw new Error(`PDF를 이미지로 변환하는 데 실패했습니다: ${errorMessage}`);
    }
    
    console.log("PDF를 이미지로 변환 완료");
    
    // 변환된 이미지 파일 목록 가져오기
    const imageFiles = [];
    for await (const entry of Deno.readDir(tempDir)) {
      if (entry.isFile && entry.name.endsWith(".png")) {
        imageFiles.push(entry.name);
      }
    }
    
    // 페이지 번호 순서대로 정렬
    imageFiles.sort((a, b) => {
      const numA = parseInt(a.replace(/[^0-9]/g, ""));
      const numB = parseInt(b.replace(/[^0-9]/g, ""));
      return numA - numB;
    });
    
    console.log(`변환된 이미지 파일 수: ${imageFiles.length}`);
    
    // 결과 이미지 파일 경로 목록 (페이지별 좌우 이미지)
    const pageImages: Record<string, { left: string; right: string }> = {};
    
    // 각 이미지를 좌우로 나누기
    for (const imageFile of imageFiles) {
      const imagePath = join(tempDir, imageFile);
      
      // 파일 이름에서 페이지 번호 추출
      const pageNumber = imageFile.replace(/[^0-9]/g, "");
      
      // 이미지 크기 정보 가져오기
      const identifyCommand = new Deno.Command("identify", {
        args: ["-format", "%w %h", imagePath]
      });
      
      const identifyOutput = await identifyCommand.output();
      if (!identifyOutput.success) {
        const errorMessage = new TextDecoder().decode(identifyOutput.stderr);
        throw new Error(`이미지 크기 정보를 가져오는 데 실패했습니다: ${errorMessage}`);
      }

      // 이미지 크기 조정 및 좌우 분할
      // 왼쪽 이미지 생성
      const leftImagePath = join(outputDir, `page_${pageNumber}_left.png`);
      const leftCommand = new Deno.Command("convert", {
        args: [
          imagePath,
          "-resize", `x${targetHeight}`,  // 높이에 맞게 크기 조정
          "-gravity", "West",             // 왼쪽 부분 선택
          "-crop", "50%x100%+0+0",        // 왼쪽 절반 자르기
          leftImagePath
        ]
      });
      
      const leftOutput = await leftCommand.output();
      if (!leftOutput.success) {
        const errorMessage = new TextDecoder().decode(leftOutput.stderr);
        throw new Error(`페이지 ${pageNumber}의 왼쪽 이미지 생성에 실패했습니다: ${errorMessage}`);
      }
      
      // 오른쪽 이미지 생성
      const rightImagePath = join(outputDir, `page_${pageNumber}_right.png`);
      const rightCommand = new Deno.Command("convert", {
        args: [
          imagePath,
          "-resize", `x${targetHeight}`,  // 높이에 맞게 크기 조정
          "-gravity", "East",             // 오른쪽 부분 선택
          "-crop", "50%x100%+0+0",        // 오른쪽 절반 자르기
          rightImagePath
        ]
      });
      
      const rightOutput = await rightCommand.output();
      if (!rightOutput.success) {
        const errorMessage = new TextDecoder().decode(rightOutput.stderr);
        throw new Error(`페이지 ${pageNumber}의 오른쪽 이미지 생성에 실패했습니다: ${errorMessage}`);
      }
      
      console.log(`페이지 ${pageNumber} 처리 완료: ${leftImagePath}, ${rightImagePath}`);
      
      // 페이지별 이미지 경로 저장
      pageImages[pageNumber] = {
        left: leftImagePath,
        right: rightImagePath
      };
    }
    
    // 임시 디렉토리 정리
    for await (const entry of Deno.readDir(tempDir)) {
      await Deno.remove(join(tempDir, entry.name));
    }
    await Deno.remove(tempDir);
    
    console.log(`모든 이미지가 '${outputDir}' 폴더에 저장되었습니다.`);
    
    // 요청한 순서대로 이미지 경로 배열 생성 (1_right, 2_left, 2_right, 1_left)
    const resultImagePaths: string[] = [];
    
    // 페이지 번호 목록 가져오기 (정렬된 상태)
    const pageNumbers = Object.keys(pageImages).sort((a, b) => parseInt(a) - parseInt(b));
    
    if (pageNumbers.length >= 1) {
      resultImagePaths.push(pageImages[pageNumbers[0]].right); // 1_right
    }
    
    if (pageNumbers.length >= 2) {
      resultImagePaths.push(pageImages[pageNumbers[1]].left);  // 2_left
      resultImagePaths.push(pageImages[pageNumbers[1]].right); // 2_right
    }
    
    if (pageNumbers.length >= 1) {
      resultImagePaths.push(pageImages[pageNumbers[0]].left);  // 1_left
    }
    
    // 추가 페이지가 있다면 순서대로 추가
    for (let i = 2; i < pageNumbers.length; i++) {
      resultImagePaths.push(pageImages[pageNumbers[i]].left);
      resultImagePaths.push(pageImages[pageNumbers[i]].right);
    }
    
    return resultImagePaths;
  } catch (error) {
    console.error("PDF 처리 중 오류 발생:", error);
    throw error;
  }
}

/**
 * 이미지 파일을 Supabase Storage에 업로드하는 함수
 * @param imagePaths 업로드할 이미지 파일 경로 목록
 * @returns 업로드된 이미지 URL 목록
 */
async function uploadImagesToSupabase(imagePaths: string[]): Promise<string[]> {
  const uploadedUrls: string[] = [];
  const timestamp = Date.now();
  
  for (let i = 0; i < imagePaths.length; i++) {
    const imagePath = imagePaths[i];
    const fileName = imagePath.split('/').pop() || `image_${i}.png`;
    const storagePath = `/${USER_ID}/bulletins_${timestamp}_${i}.png`;
    
    try {
      // 이미지 파일 읽기
      const fileData = await Deno.readFile(imagePath);
      
      // Supabase Storage에 업로드
      const { error } = await supabase.storage
        .from('posts')
        .upload(storagePath, fileData, {
          cacheControl: '3600',
          upsert: true,
          contentType: 'image/png'
        });
      
      if (error) {
        console.error(`이미지 업로드 실패 (${fileName}):`, error);
        continue;
      }
      
      // 업로드된 이미지의 공개 URL 가져오기
      const { data } = supabase.storage
        .from('posts')
        .getPublicUrl(storagePath);
      
      if (data && data.publicUrl) {
        uploadedUrls.push(data.publicUrl);
        console.log(`이미지 업로드 성공 (${fileName}): ${data.publicUrl}`);
      }
    } catch (error) {
      console.error(`이미지 업로드 중 오류 발생 (${fileName}):`, error);
    }
  }
  
  return uploadedUrls;
}


/**
 * 동일한 제목의 게시물이 있는지 확인하는 함수
 * @param title 게시물 제목
 * @returns 존재하는 게시물 ID, 없으면 null
 */
async function checkExistingPost(title: string): Promise<number | null> {
  try {
    // 1. 동일한 제목의 게시물이 있는지 확인
    const { data: existingPosts } = await supabase
      .from('posts')
      .select('id')
      .eq('title', title)
      .single();
    
    if (existingPosts) {
      console.log(`동일한 제목의 게시물이 이미 존재합니다: ${title}`);
      return existingPosts.id;
    } else {
      console.log(`동일한 제목의 게시물이 없습니다: ${title}`);
      return null;
    }
  } catch (error) {
    console.error("게시물 조회 중 오류 발생:", error);
    return null;  
  }
}
/**
 * 주보 이미지를 게시물로 등록하는 함수
 * @param imageUrls 업로드된 이미지 URL 목록
 * @param title 게시물 제목
 * @returns 생성된 게시물 ID
 */
async function createBulletinPost(imageUrls: string[], title: string): Promise<number | null> {
  if (imageUrls.length === 0) {
    console.error("업로드된 이미지가 없습니다.");
    return null;
  }
  
  try {
    // 게시물 데이터 준비
    const postData = {
      title,
      category_id: CATEGORY_ID,
      user_id: USER_ID,
      media_urls: imageUrls,
      active: true,
      created_at: new Date().toISOString()
    };
    
    // 게시물 생성
    const { data, error } = await supabase
      .from('posts')
      .insert(postData)
      .select('id')
      .single();
    
    if (error) {
      console.error("게시물 생성 실패:", error);
      return null;
    }
    
    console.log(`게시물 생성 성공 (ID: ${data.id})`);
    return data.id;
  } catch (error) {
    console.error("게시물 생성 중 오류 발생:", error);
    return null;
  }
}

/**
 * PDF를 처리하고 Supabase에 업로드하는 메인 함수
 * @param pdfPath PDF 파일 경로
 * @param outputDir 출력 디렉토리 경로
 * @param title 게시물 제목
 */
async function processPdfAndUpload(pdfPath: string, outputDir: string, title: string) {
  try {
    // 1. PDF를 이미지로 변환
    const imagePaths = await pdfToSplitImages(pdfPath, outputDir);

    // 2. 동일한 제목의 게시물이 있는지 확인
    const existedId = await checkExistingPost(title);
    if (existedId) {
      return {
        success: true,
        message: `동일한 제목의 게시물이 이미 존재합니다: ${title}`,
        existedId,
        imageUrls: []
      };
    }
    
    // 2. 이미지를 Supabase에 업로드
    const imageUrls = await uploadImagesToSupabase(imagePaths);
    
    // 3. 게시물 생성
    const postId = await createBulletinPost(imageUrls, title);
    
    return {
      success: true,
      message: `주보 업로드 완료: ${imageUrls.length}개 이미지, 게시물 ID: ${postId}`,
      postId,
      imageUrls
    };
  } catch (error) {
    console.error("PDF 처리 및 업로드 중 오류 발생:", error);
    return {
      success: false,
      message: `오류 발생: ${error instanceof Error ? error.message : '알 수 없는 오류'}`,
      error
    };
  }
}

// HTTP 서버 설정 - 로컬 테스트 모드가 아닐 때만 실행
if (!import.meta.main) {
  serve(async (req) => {
    // CORS 처리
    if (req.method === 'OPTIONS') {
      return new Response('ok', {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST',
          'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        }
      });
    }
    
    // POST 요청만 처리
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: '잘못된 요청 메서드입니다. POST 요청만 허용됩니다.' }),
        {
          status: 405,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          }
        }
      );
    }
    
    try {
      // 요청 본문 파싱
      const requestData = await req.json();
      const { pdfUrl, title, useWebsite } = requestData;
      
      let finalPdfUrl = pdfUrl;
      let finalTitle = title;
      
      // 웹사이트에서 PDF 가져오기 옵션이 활성화된 경우
      if (useWebsite === true || !finalPdfUrl) {
        try {
          console.log("교회 웹사이트에서 최신 주보 정보를 가져옵니다.");
          const websiteData = await fetchLatestBulletinPdf();
          finalPdfUrl = websiteData.pdfUrl;
          
          // 제목이 제공되지 않은 경우에만 웹사이트에서 가져온 제목 사용
          if (!finalTitle) {
            finalTitle = websiteData.title;
          }
        } catch (error) {
          return new Response(
            JSON.stringify({ 
              error: '교회 웹사이트에서 주보 정보를 가져오는 데 실패했습니다.',
              details: error instanceof Error ? error.message : '알 수 없는 오류'
            }),
            {
              status: 400,
              headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
              }
            }
          );
        }
      }
      
      if (!finalPdfUrl) {
        return new Response(
          JSON.stringify({ error: 'PDF URL이 필요합니다.' }),
          {
            status: 400,
            headers: {
              'Content-Type': 'application/json',
              'Access-Control-Allow-Origin': '*',
            }
          }
        );
      }
      
      // PDF 파일 다운로드
      const pdfResponse = await fetch(finalPdfUrl);
      if (!pdfResponse.ok) {
        return new Response(
          JSON.stringify({ error: 'PDF 파일을 다운로드할 수 없습니다.' }),
          {
            status: 400,
            headers: {
              'Content-Type': 'application/json',
              'Access-Control-Allow-Origin': '*',
            }
          }
        );
      }
      
      // 임시 디렉토리 생성
      const tempDir = await Deno.makeTempDir();
      const pdfPath = join(tempDir, 'bulletin.pdf');
      const outputDir = join(tempDir, 'output');
      
      // PDF 파일 저장
      const pdfData = await pdfResponse.arrayBuffer();
      await Deno.writeFile(pdfPath, new Uint8Array(pdfData));
      
      // 제목이 제공되지 않은 경우 현재 날짜 사용
      if (!finalTitle) {
        const now = new Date();
        const year = now.getFullYear().toString().slice(-2);
        const month = (now.getMonth() + 1).toString().padStart(2, '0');
        const day = now.getDate().toString().padStart(2, '0');
        finalTitle = `${year}/${month}/${day} 주보`;
      }
      
      // PDF 처리 및 업로드
      const result = await processPdfAndUpload(pdfPath, outputDir, finalTitle);
      
      // 임시 파일 정리
      try {
        await Deno.remove(pdfPath);
        await Deno.remove(tempDir, { recursive: true });
      } catch (e) {
        console.error('임시 파일 정리 중 오류 발생:', e);
      }
      
      return new Response(
        JSON.stringify(result),
        {
          status: result.success ? 200 : 500,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          }
        }
      );
    } catch (error) {
      console.error('요청 처리 중 오류 발생:', error);
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: error instanceof Error ? error.message : '알 수 없는 오류' 
        }),
        {
          status: 500,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          }
        }
      );
    }
  });
}

// 로컬 테스트용 코드 (HTTP 서버가 실행되지 않을 때만 실행)
if (import.meta.main) {
  console.log("로컬 테스트 모드로 실행 중...");
  
  try {
    // 교회 웹사이트에서 최신 주보 게시물 찾기
    console.log(`교회 웹사이트에서 최신 주보 정보를 가져오는 중... (${CHURCH_WEBSITE_URL})`);
    
    // 웹사이트 HTML 가져오기
    const response = await fetch(CHURCH_WEBSITE_URL);
    if (!response.ok) {
      throw new Error(`웹사이트 접근 실패: ${response.status} ${response.statusText}`);
    }
    
    const html = await response.text();
    
    // 최신 주보 게시물 링크 찾기
    const latestPostRegex = /<a[^>]*href="([^"]*\/article\/교회소식\/[^"]*)"[^>]*>\s*(\d{4}년\s*\d{1,2}월\s*\d{1,2}일\s*교회소식)/i;
    const latestPostMatch = html.match(latestPostRegex);
    
    if (!latestPostMatch || !latestPostMatch[1]) {
      throw new Error("웹사이트에서 최신 주보 게시물을 찾을 수 없습니다.");
    }
    
    // 게시물 URL 추출 및 절대 경로로 변환
    let postUrl = latestPostMatch[1];
    // '#none' 제거
    postUrl = postUrl.replace(/#none$/, '');
    
    if (postUrl.startsWith('//')) {
      postUrl = 'https:' + postUrl;
    } else if (!postUrl.startsWith('http')) {
      // 도메인 추출
      const domainMatch = CHURCH_WEBSITE_URL.match(/^(https?:\/\/[^\/]+)/);
      const domain = domainMatch ? domainMatch[1] : 'https://xn--9d0by7j11iba736zkqd.com';
      postUrl = domain + (postUrl.startsWith('/') ? '' : '/') + postUrl;
    }
    
    console.log(`최신 주보 게시물 URL: ${postUrl}`);
    
    // 게시물 페이지 가져오기
    console.log("게시물 페이지 가져오는 중...");
    const postResponse = await fetch(postUrl);
    if (!postResponse.ok) {
      throw new Error(`게시물 페이지 접근 실패: ${postResponse.status} ${postResponse.statusText}`);
    }
    
    const postHtml = await postResponse.text();
    
    // 다운로드 링크 찾기 (JavaScript 함수 호출 패턴)
    console.log("다운로드 링크 찾는 중...");
    const downloadRegex = /BOARD_READ\.file_download\('([^']+)'/i;
    const downloadMatch = postHtml.match(downloadRegex);
    
    let downloadPath = "";
    if (downloadMatch && downloadMatch[1]) {
      downloadPath = downloadMatch[1];
      console.log(`다운로드 경로 찾음: ${downloadPath}`);
    } else {
      console.log("다운로드 경로를 찾을 수 없습니다.");
      throw new Error("게시물에서 다운로드 경로를 찾을 수 없습니다.");
    }
    
    // 도메인 추출
    const domainMatch = postUrl.match(/^(https?:\/\/[^\/]+)/);
    const domain = domainMatch ? domainMatch[1] : 'https://xn--9d0by7j11iba736zkqd.com';
    
    // 다운로드 URL 구성
    const downloadUrl = domain + downloadPath;
    console.log(`최종 다운로드 URL: ${downloadUrl}`);
    
    // 제목 추출 (게시물 제목에서)
    let title = "";
    if (latestPostMatch && latestPostMatch[2]) {
      const titleText = latestPostMatch[2];
      console.log(`게시물 제목: ${titleText}`);
      
      // 날짜 추출 (예: "2025년 3월 16일 교회소식")
      const dateRegex = /(\d{4})년.*?(\d{1,2})월.*?(\d{1,2})일/;
      const dateMatch = titleText.match(dateRegex);
      
      if (dateMatch) {
        const year = dateMatch[1].slice(-2); // 4자리 연도에서 뒤의 2자리만 사용
        const month = dateMatch[2].padStart(2, '0');
        const day = dateMatch[3].padStart(2, '0');
        title = `${year}/${month}/${day} 주보`;
        console.log(`게시물 제목에서 날짜 추출: ${title}`);
      } else {
        // 파일명에서 날짜 추출 시도
        const filenameMatch = downloadPath.match(/filename=([^&]+)/);
        if (filenameMatch && filenameMatch[1]) {
          const filename = decodeURIComponent(filenameMatch[1]);
          console.log(`파일명: ${filename}`);
          
          // 날짜 추출 (예: "2025년(61-11호) 3월 16일.pdf")
          const fileDateRegex = /(\d{4})년.*?(\d{1,2})월.*?(\d{1,2})일/;
          const fileDateMatch = filename.match(fileDateRegex);
          
          if (fileDateMatch) {
            const year = fileDateMatch[1].slice(-2);
            const month = fileDateMatch[2].padStart(2, '0');
            const day = fileDateMatch[3].padStart(2, '0');
            title = `${year}/${month}/${day} 주보`;
            console.log(`파일명에서 날짜 추출: ${title}`);
          } else {
            // 숫자 추출 시도
            const numbers = filename.match(/\d+/g);
            if (numbers && numbers.length >= 3) {
              // 첫 번째 숫자가 4자리면 연도로 간주
              let yearIndex = 0;
              let monthIndex = 1;
              let dayIndex = 2;
              
              // 첫 번째 숫자가 4자리가 아니면 다른 패턴 시도
              if (numbers[0].length !== 4) {
                // 다른 숫자 중 4자리 숫자 찾기
                for (let i = 0; i < numbers.length; i++) {
                  if (numbers[i].length === 4) {
                    yearIndex = i;
                    monthIndex = (i + 1) % numbers.length;
                    dayIndex = (i + 2) % numbers.length;
                    break;
                  }
                }
              }
              
              const year = numbers[yearIndex].slice(-2);
              const month = parseInt(numbers[monthIndex]) <= 12 ? 
                            numbers[monthIndex].padStart(2, '0') : 
                            numbers[dayIndex].padStart(2, '0');
              const day = parseInt(numbers[monthIndex]) <= 12 ? 
                          numbers[dayIndex].padStart(2, '0') : 
                          numbers[monthIndex].padStart(2, '0');
              
              title = `${year}/${month}/${day} 주보`;
              console.log(`숫자 추출로 제목 설정: ${title}`);
            } else {
              // 현재 날짜 사용
              const now = new Date();
              const year = now.getFullYear().toString().slice(-2);
              const month = (now.getMonth() + 1).toString().padStart(2, '0');
              const day = now.getDate().toString().padStart(2, '0');
              title = `${year}/${month}/${day} 주보`;
              console.log(`날짜 추출 실패, 현재 날짜로 제목 설정: ${title}`);
            }
          }
        } else {
          // 현재 날짜 사용
          const now = new Date();
          const year = now.getFullYear().toString().slice(-2);
          const month = (now.getMonth() + 1).toString().padStart(2, '0');
          const day = now.getDate().toString().padStart(2, '0');
          title = `${year}/${month}/${day} 주보`;
          console.log(`파일명 추출 실패, 현재 날짜로 제목 설정: ${title}`);
        }
      }
    } else {
      // 현재 날짜 사용
      const now = new Date();
      const year = now.getFullYear().toString().slice(-2);
      const month = (now.getMonth() + 1).toString().padStart(2, '0');
      const day = now.getDate().toString().padStart(2, '0');
      title = `${year}/${month}/${day} 주보`;
      console.log(`게시물 제목 추출 실패, 현재 날짜로 제목 설정: ${title}`);
    }
    
    // PDF 파일 다운로드 시도
    console.log(`PDF 다운로드 시도 중...`);
    const pdfResponse = await fetch(downloadUrl);
    
    console.log(`PDF 다운로드 응답 상태: ${pdfResponse.status} ${pdfResponse.statusText}`);
    console.log(`응답 Content-Type: ${pdfResponse.headers.get('Content-Type')}`);
    
    if (!pdfResponse.ok) {
      throw new Error(`PDF 다운로드 실패: ${pdfResponse.status} ${pdfResponse.statusText}`);
    }
    
    // 응답 크기 확인
    const contentLength = pdfResponse.headers.get('Content-Length');
    console.log(`응답 크기: ${contentLength ? parseInt(contentLength) / 1024 : '알 수 없음'} KB`);
    
    // PDF 파일 저장
    const pdfData = await pdfResponse.arrayBuffer();
    console.log(`다운로드된 데이터 크기: ${pdfData.byteLength / 1024} KB`);
    
    // 임시 디렉토리 생성
    await ensureDir(OUTPUT_DIR);
    const tempPdfPath = join(OUTPUT_DIR, "bulletin.pdf");
    
    await Deno.writeFile(tempPdfPath, new Uint8Array(pdfData));
    console.log(`PDF 파일 저장 완료: ${tempPdfPath}`);
    
    // 파일 크기 확인
    const fileInfo = await Deno.stat(tempPdfPath);
    console.log(`저장된 파일 크기: ${fileInfo.size / 1024} KB`);
    
    // PDF 처리 및 업로드
    console.log(`PDF 처리 및 Supabase 업로드 시작...`);
    console.log(`게시물 제목: ${title}`);
    
    const result = await processPdfAndUpload(tempPdfPath, OUTPUT_DIR, title);
    console.log("처리 결과:", result);
    
    console.log("작업이 완료되었습니다. 프로그램을 종료합니다.");
  } catch (error) {
    console.error("실행 중 오류 발생:", error);
    Deno.exit(1);
  }
}

// deno run -A supabase/functions/upload_bulletin/index.ts
