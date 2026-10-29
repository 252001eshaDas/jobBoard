import io

from fastapi import FastAPI, File, HTTPException, UploadFile
from pydantic import BaseModel
from pypdf import PdfReader
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

app = FastAPI(title="Resume AI service")


class MatchIn(BaseModel):
    resume_text: str
    job_text: str


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/parse-resume")
async def parse_resume(file: UploadFile = File(...)):
    if file.content_type != "application/pdf":
        raise HTTPException(status_code=415, detail="Only PDF resumes are supported")
    data = await file.read()
    reader = PdfReader(io.BytesIO(data))
    text = "\n".join((page.extract_text() or "") for page in reader.pages)
    return {"text": text.strip(), "pages": len(reader.pages)}


@app.post("/match")
def match(body: MatchIn):
    # Baseline: TF-IDF cosine similarity. Upgrade later to sentence-transformers embeddings.
    try:
        vec = TfidfVectorizer(stop_words="english", ngram_range=(1, 2))
        m = vec.fit_transform([body.resume_text, body.job_text])
    except ValueError:
        raise HTTPException(status_code=422, detail="Not enough text to compare")
    score = float(cosine_similarity(m[0], m[1])[0][0])
    terms = vec.get_feature_names_out()
    resume_vec, job_vec = m[0].toarray()[0], m[1].toarray()[0]
    matched = [terms[i] for i in range(len(terms)) if resume_vec[i] > 0 and job_vec[i] > 0]
    missing = [terms[i] for i in range(len(terms)) if job_vec[i] > 0 and resume_vec[i] == 0]
    return {
        "score": round(score * 100, 1),
        "matched_terms": matched[:30],
        "missing_terms": missing[:30],
    }
