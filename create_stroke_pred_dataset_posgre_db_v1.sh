docker exec analytics-postgres psql -U analytics_user -d postgres -c "CREATE DATABASE stroke_data_exploration;"

# Execute tables creation (run in stroke_data_exploration context)
docker exec analytics-postgres psql -U analytics_user -d stroke_data_exploration -c "
-- Raw stroke dataset table 
CREATE TABLE IF NOT EXISTS stroke_raw_data (
    id VARCHAR(50) PRIMARY KEY,
    gender VARCHAR(10),
    age DECIMAL(5,2),
    hypertension BOOLEAN,
    heart_disease BOOLEAN,
    ever_married VARCHAR(3),
    work_type VARCHAR(50),
    residence_type VARCHAR(10),
    avg_glucose_level DECIMAL(8,3),
    bmi DECIMAL(5,2),
    smoking_status VARCHAR(20),
    stroke BOOLEAN,
    partition INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    batch_id VARCHAR(50)
);

-- Dataset overview and summary statistics
CREATE TABLE IF NOT EXISTS dataset_overview (
    id SERIAL PRIMARY KEY,
    total_records INTEGER,
    unique_patients INTEGER,
    avg_age DECIMAL(8,6),
    avg_glucose DECIMAL(10,6),
    avg_bmi DECIMAL(10,6),
    analysis_date DATE DEFAULT CURRENT_DATE
);

-- Stroke distribution analysis
CREATE TABLE IF NOT EXISTS stroke_distribution (
    id SERIAL PRIMARY KEY,
    stroke BOOLEAN,
    count INTEGER,
    percentage DECIMAL(5,2),
    analysis_date DATE DEFAULT CURRENT_DATE
);

-- Demographic analysis tables
CREATE TABLE IF NOT EXISTS gender_analysis (
    id SERIAL PRIMARY KEY,
    gender VARCHAR(10),
    total INTEGER,
    stroke_cases INTEGER,
    stroke_rate_percent DECIMAL(5,2),
    analysis_date DATE DEFAULT CURRENT_DATE
);

CREATE TABLE IF NOT EXISTS age_group_analysis (
    id SERIAL PRIMARY KEY,
    age_group VARCHAR(20),
    total INTEGER,
    stroke_cases INTEGER,
    stroke_rate_percent DECIMAL(5,2),
    analysis_date DATE DEFAULT CURRENT_DATE
);

-- Medical factors analysis
CREATE TABLE IF NOT EXISTS hypertension_heart_disease_analysis (
    id SERIAL PRIMARY KEY,
    hypertension BOOLEAN,
    heart_disease BOOLEAN,
    total INTEGER,
    stroke_cases INTEGER,
    stroke_rate_percent DECIMAL(5,2),
    analysis_date DATE DEFAULT CURRENT_DATE
);

CREATE TABLE IF NOT EXISTS smoking_analysis (
    id SERIAL PRIMARY KEY,
    smoking_status VARCHAR(20),
    total INTEGER,
    stroke_cases INTEGER,
    stroke_rate_percent DECIMAL(5,2),
    analysis_date DATE DEFAULT CURRENT_DATE
);

-- Lifestyle and work analysis
CREATE TABLE IF NOT EXISTS work_type_analysis (
    id SERIAL PRIMARY KEY,
    work_type VARCHAR(50),
    total INTEGER,
    stroke_cases INTEGER,
    stroke_rate_percent DECIMAL(5,2),
    analysis_date DATE DEFAULT CURRENT_DATE
);

CREATE TABLE IF NOT EXISTS residence_analysis (
    id SERIAL PRIMARY KEY,
    residence_type VARCHAR(10),
    total INTEGER,
    stroke_cases INTEGER,
    stroke_rate_percent DECIMAL(5,2),
    avg_age DECIMAL(5,2),
    analysis_date DATE DEFAULT CURRENT_DATE
);

-- Numerical analysis tables
CREATE TABLE IF NOT EXISTS glucose_analysis (
    id SERIAL PRIMARY KEY,
    stroke BOOLEAN,
    avg_glucose DECIMAL(8,2),
    min_glucose DECIMAL(8,2),
    max_glucose DECIMAL(8,2),
    std_glucose DECIMAL(8,2),
    analysis_date DATE DEFAULT CURRENT_DATE
);

CREATE TABLE IF NOT EXISTS bmi_analysis (
    id SERIAL PRIMARY KEY,
    stroke BOOLEAN,
    avg_bmi DECIMAL(6,2),
    min_bmi DECIMAL(6,2),
    max_bmi DECIMAL(6,2),
    analysis_date DATE DEFAULT CURRENT_DATE
);

-- Multi-factor risk analysis
CREATE TABLE IF NOT EXISTS multi_factor_risk (
    id SERIAL PRIMARY KEY,
    hypertension BOOLEAN,
    heart_disease BOOLEAN,
    smoking_status VARCHAR(20),
    total INTEGER,
    stroke_cases INTEGER,
    stroke_rate_percent DECIMAL(5,2),
    analysis_date DATE DEFAULT CURRENT_DATE
);

-- Data quality metrics
CREATE TABLE IF NOT EXISTS data_quality_metrics (
    id SERIAL PRIMARY KEY,
    metric_name VARCHAR(100),
    total_records INTEGER,
    issue_count INTEGER,
    issue_percentage DECIMAL(5,2),
    analysis_date DATE DEFAULT CURRENT_DATE
);

-- Correlation analysis
CREATE TABLE IF NOT EXISTS correlation_analysis (
    id SERIAL PRIMARY KEY,
    stroke BOOLEAN,
    age_glucose_correlation DECIMAL(6,3),
    analysis_date DATE DEFAULT CURRENT_DATE
);

-- High-risk profiles
CREATE TABLE IF NOT EXISTS high_risk_profiles (
    id SERIAL PRIMARY KEY,
    high_risk_count INTEGER,
    percentage DECIMAL(5,2),
    criteria_description TEXT,
    analysis_date DATE DEFAULT CURRENT_DATE
);

-- Numerical summary statistics
CREATE TABLE IF NOT EXISTS numerical_summary (
    id SERIAL PRIMARY KEY,
    column_name VARCHAR(50),
    min_value DECIMAL(10,2),
    max_value DECIMAL(10,2),
    avg_value DECIMAL(10,2),
    std_value DECIMAL(10,2),
    analysis_date DATE DEFAULT CURRENT_DATE
);

-- Patient risk scoring
CREATE TABLE IF NOT EXISTS patient_risk_scores (
    id SERIAL PRIMARY KEY,
    patient_id VARCHAR(50),
    age DECIMAL(5,2),
    avg_glucose_level DECIMAL(8,3),
    bmi DECIMAL(5,2),
    hypertension BOOLEAN,
    heart_disease BOOLEAN,
    stroke BOOLEAN,
    risk_score DECIMAL(8,2),
    risk_rank INTEGER,
    analysis_date DATE DEFAULT CURRENT_DATE
);

-- Pivot analysis tables
CREATE TABLE IF NOT EXISTS age_gender_pivot (
    id SERIAL PRIMARY KEY,
    gender VARCHAR(10),
    under_50_stroke_rate DECIMAL(5,2),
    over_50_stroke_rate DECIMAL(5,2),
    analysis_date DATE DEFAULT CURRENT_DATE
);

-- Exploration findings and insights
CREATE TABLE IF NOT EXISTS exploration_findings (
    id SERIAL PRIMARY KEY,
    insight_category VARCHAR(100),
    finding_description TEXT,
    metric_value DECIMAL(15,6),
    significance VARCHAR(50),
    recommendation TEXT,
    analysis_date DATE DEFAULT CURRENT_DATE
);

-- Feature importance analysis
CREATE TABLE IF NOT EXISTS feature_importance (
    id SERIAL PRIMARY KEY,
    feature_name VARCHAR(100),
    correlation_with_stroke DECIMAL(6,3),
    importance_score DECIMAL(6,3),
    analysis_date DATE DEFAULT CURRENT_DATE
);

-- Creating indexes for better performance
CREATE INDEX IF NOT EXISTS idx_stroke_raw_data_id ON stroke_raw_data(id);
CREATE INDEX IF NOT EXISTS idx_stroke_raw_data_stroke ON stroke_raw_data(stroke);
CREATE INDEX IF NOT EXISTS idx_stroke_raw_data_age ON stroke_raw_data(age);
CREATE INDEX IF NOT EXISTS idx_patient_risk_scores_score ON patient_risk_scores(risk_score DESC);

-- Granting privileges to analytics_user
GRANT ALL PRIVILEGES ON DATABASE stroke_data_exploration TO analytics_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO analytics_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO analytics_user;"

