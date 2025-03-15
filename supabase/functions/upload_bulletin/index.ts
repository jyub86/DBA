// SUPABASE EDGEFUNCTION이 아님
// PDF를 이미지로 변환하고 좌우로 나누는 함수
const PDF_PATH = "";
const OUTPUT_DIR = "build/temp";

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
      
      const dimensionsText = new TextDecoder().decode(identifyOutput.stdout).trim();
      const [width, height] = dimensionsText.split(" ").map(Number);
      
      // 비율에 맞게 이미지 크기 조정
      const scale = targetHeight / height;
      const scaledWidth = Math.floor(width * scale);
      
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
      const { pdfUrl, title } = requestData;
      
      if (!pdfUrl) {
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
      const pdfResponse = await fetch(pdfUrl);
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
      
      // 현재 날짜를 YY/MM/DD 형식으로 포맷팅
      const now = new Date();
      const year = now.getFullYear().toString().slice(-2);
      const month = (now.getMonth() + 1).toString().padStart(2, '0');
      const day = now.getDate().toString().padStart(2, '0');
      const formattedDate = `${year}/${month}/${day}`;
      
      // PDF 처리 및 업로드
      const postTitle = title || `${formattedDate} 주보`;
      const result = await processPdfAndUpload(pdfPath, outputDir, postTitle);
      
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
  console.log(`PDF 경로: ${PDF_PATH}`);
  console.log(`출력 디렉토리: ${OUTPUT_DIR}`);
  
  try {
    // 현재 날짜를 YY/MM/DD 형식으로 포맷팅
    const now = new Date();
    const year = now.getFullYear().toString().slice(-2);
    const month = (now.getMonth() + 1).toString().padStart(2, '0');
    const day = now.getDate().toString().padStart(2, '0');
    const formattedDate = `${year}/${month}/${day}`;
    
    const title = `${formattedDate} 주보`;
    console.log(`게시물 제목: ${title}`);
    
    const result = await processPdfAndUpload(PDF_PATH, OUTPUT_DIR, title);
    console.log("처리 결과:", result);
    console.log("작업이 완료되었습니다. 프로그램을 종료합니다.");
  } catch (error) {
    console.error("실행 중 오류 발생:", error);
    Deno.exit(1);
  }
}