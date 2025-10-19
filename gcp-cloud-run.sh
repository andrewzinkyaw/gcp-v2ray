#!/bin/bash
set -euo pipefail

# ===== Colors =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

# ===== Validators =====
validate_uuid() {
    local uuid_pattern='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    [[ $1 =~ $uuid_pattern ]] || { error "Invalid UUID format: $1"; return 1; }
}

validate_bot_token() {
    local token_pattern='^[0-9]{8,10}:[a-zA-Z0-9_-]{35}$'
    [[ $1 =~ $token_pattern ]] || { error "Invalid Telegram Bot Token format"; return 1; }
}

validate_channel_id() { [[ $1 =~ ^-?[0-9]+$ ]] || { error "Invalid Channel ID"; return 1; } }
validate_chat_id() { [[ $1 =~ ^-?[0-9]+$ ]] || { error "Invalid Chat ID"; return 1; } }

validate_url() {
    local url="$1"
    local url_pattern='^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/[a-zA-Z0-9.~:/?#@!$&'"'"'()+,;=-]*)?$'
    local telegram_pattern='^https?://t.me/[a-zA-Z0-9_]+$'
    [[ "$url" =~ $telegram_pattern || "$url" =~ $url_pattern ]] || { error "Invalid URL: $url"; return 1; }
}

# ===== CPU & Memory selection =====
select_cpu() {
    echo; info "=== CPU Configuration ==="
    echo "1. 1 CPU Core (Default)"
    echo "2. 2 CPU Cores"
    echo "3. 4 CPU Cores"
    echo "4. 8 CPU Cores"
    while true; do
        read -p "Select CPU (1-4): " cpu_choice
        case $cpu_choice in
            1) CPU="1"; break;;
            2) CPU="2"; break;;
            3) CPU="4"; break;;
            4) CPU="8"; break;;
            *) echo "Invalid selection (1-4)";;
        esac
    done
    info "Selected CPU: $CPU core(s)"
}

select_memory() {
    echo; info "=== Memory Configuration ==="
    echo "1. 512Mi"
    echo "2. 1Gi"
    echo "3. 2Gi"
    echo "4. 4Gi"
    echo "5. 8Gi"
    echo "6. 16Gi"
    while true; do
        read -p "Select memory (1-6): " memory_choice
        case $memory_choice in
            1) MEMORY="512Mi"; break;;
            2) MEMORY="1Gi"; break;;
            3) MEMORY="2Gi"; break;;
            4) MEMORY="4Gi"; break;;
            5) MEMORY="8Gi"; break;;
            6) MEMORY="16Gi"; break;;
            *) echo "Invalid (1-6)";;
        esac
    done
    info "Selected Memory: $MEMORY"
}

select_region() {
    echo
    info "=== Region Selection ==="
    echo "
1. us-central1 (Iowa, USA 🇺🇸)
2. us-west1 (Oregon, USA 🇺🇸)
3. us-east1 (South Carolina, USA 🇺🇸)
4. europe-west1 (Belgium 🇧🇪)
5. asia-southeast1 (Singapore 🇸🇬)
6. asia-southeast2 (Indonesia 🇮🇩)
7. asia-northeast1 (Tokyo, Japan 🇯🇵)
8. asia-east1 (Taiwan 🇹🇼)
"
    while true; do
        read -p "Select region (1-8): " region_choice
        case $region_choice in
            1) REGION="us-central1"; break;;
            2) REGION="us-west1"; break;;
            3) REGION="us-east1"; break;;
            4) REGION="europe-west1"; break;;
            5) REGION="asia-southeast1"; break;;
            6) REGION="asia-southeast2"; break;;
            7) REGION="asia-northeast1"; break;;
            8) REGION="asia-east1"; break;;
            *) echo "Invalid (1-8)";;
        esac
    done
    info "Selected region: $REGION"
}

# ===== Telegram configuration =====
select_telegram_destination() {
    echo; info "=== Telegram Destination ==="
    echo "1. Channel"
    echo "2. Bot"
    echo "3. Both"
    echo "4. None"
    while true; do
        read -p "Select destination (1-4): " telegram_choice
        case $telegram_choice in
            1) TELEGRAM_DESTINATION="channel"; break;;
            2) TELEGRAM_DESTINATION="bot"; break;;
            3) TELEGRAM_DESTINATION="both"; break;;
            4) TELEGRAM_DESTINATION="none"; break;;
            *) echo "Invalid (1-4)";;
        esac
    done
}

get_channel_url() {
    echo; info "=== Channel Configuration ==="
    echo "Default URL: https://t.me/trenzych"
    while true; do
        read -p "Enter Channel URL [default: https://t.me/trenzych]: " CHANNEL_URL
        CHANNEL_URL=${CHANNEL_URL:-"https://t.me/trenzych"}
        CHANNEL_URL=$(echo "$CHANNEL_URL" | sed 's|/*$||')
        validate_url "$CHANNEL_URL" && break
    done
    read -p "Enter Channel Name [default: TRENZYCH]: " CHANNEL_NAME
    CHANNEL_NAME=${CHANNEL_NAME:-"TRENZYCH"}
}

get_telegram_ids() {
    if [[ "$TELEGRAM_DESTINATION" == "bot" || "$TELEGRAM_DESTINATION" == "both" ]]; then
        while true; do
            read -p "Enter Telegram Chat ID (bot): " TELEGRAM_CHAT_ID
            validate_chat_id "$TELEGRAM_CHAT_ID" && break
        done
    fi
    if [[ "$TELEGRAM_DESTINATION" == "channel" || "$TELEGRAM_DESTINATION" == "both" ]]; then
        while true; do
            read -p "Enter Telegram Channel ID (number with -100 prefix): " TELEGRAM_CHANNEL_ID
            validate_channel_id "$TELEGRAM_CHANNEL_ID" && break
        done
    fi
}

# ===== User input =====
get_user_input() {
    echo; info "=== Service Configuration ==="
    while true; do read -p "Enter service name: " SERVICE_NAME; [[ -n "$SERVICE_NAME" ]] && break; done
    while true; do read -p "Enter UUID [default: 9c910024-714e-4221-81c6-41ca9856e7ab]: " UUID
        UUID=${UUID:-"9c910024-714e-4221-81c6-41ca9856e7ab"}
        validate_uuid "$UUID" && break
    done
    if [[ "$TELEGRAM_DESTINATION" != "none" ]]; then
        while true; do read -p "Enter Telegram Bot Token: " TELEGRAM_BOT_TOKEN; validate_bot_token "$TELEGRAM_BOT_TOKEN" && break; done
    fi
    read -p "Enter host domain [default: m.googleapis.com]: " HOST_DOMAIN
    HOST_DOMAIN=${HOST_DOMAIN:-"m.googleapis.com"}
    [[ "$TELEGRAM_DESTINATION" != "none" ]] && get_channel_url
    [[ "$TELEGRAM_DESTINATION" != "none" ]] && get_telegram_ids
}

# ===== Telegram send =====
send_to_telegram() {
    local chat_id="$1"; local message="$2"; local dest_type="$3"

    local keyboard=$(cat <<EOF
{"inline_keyboard":[
  [{"text":"$CHANNEL_NAME","url":"$CHANNEL_URL"}]
]}
EOF
)
    response=$(curl -s -w "%{http_code}" -X POST -H "Content-Type: application/json" \
        -d "{\"chat_id\":\"${chat_id}\",\"text\":\"${message}\",\"parse_mode\":\"HTML\",\"disable_web_page_preview\":true,\"reply_markup\":$keyboard}" \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage")

    if [[ "${response: -3}" == "200" ]]; then
        if [[ "$dest_type" == "bot" ]]; then
            log "✅ Sent to your Telegram bot successfully."
        elif [[ "$dest_type" == "channel" ]]; then
            log "✅ Sent to Telegram channel successfully."
        fi
    else
        error "❌ Telegram send failed: ${response}"
    fi
}
check_or_select_project() {
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null || true)
    if [[ -z "$PROJECT_ID" ]]; then
        echo; info "No GCP project set. Please select or create one:"
        PROJECT_LIST=$(gcloud projects list --format="value(projectId)")
        if [[ -z "$PROJECT_LIST" ]]; then
            read -p "No projects found. Enter new project ID to create: " NEW_PROJECT
            gcloud projects create "$NEW_PROJECT"
            PROJECT_ID="$NEW_PROJECT"
        else
            select proj in $PROJECT_LIST; do
                PROJECT_ID="$proj"
                break
            done
        fi
        gcloud config set project "$PROJECT_ID"
    fi
    log "Using GCP project: $PROJECT_ID"
}

main() {
    info "=== GCP Cloud Run V2Ray Deployment ==="
    select_region
    select_cpu
    select_memory
    select_telegram_destination
    get_user_input
    check_or_select_project

    # ===== Preview times =====
    START_TIME=$(TZ='Asia/Yangon' date +"%d-%m-%Y (%I:%M %p)")
    END_TIME=$(TZ='Asia/Yangon' date -d "+5 hours" +"%d-%m-%Y (%I:%M %p)")

    # ===== Confirm deploy =====
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}💬 Confirm Deployment${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Project:${NC} ${PROJECT_ID}"
    echo -e "${YELLOW}Service:${NC} ${SERVICE_NAME}"
    echo -e "${YELLOW}Region:${NC} ${REGION}"
    echo -e "${YELLOW}CPU:${NC} ${CPU} | ${YELLOW}Memory:${NC} ${MEMORY}"
    echo -e "${YELLOW}Domain:${NC} ${HOST_DOMAIN}"
    echo -e "${YELLOW}Start:${NC} ${START_TIME}"
    echo -e "${YELLOW}End:${NC}   ${END_TIME}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -rp "Continue? (y/n) [default: y]: " CONFIRM
    CONFIRM=${CONFIRM:-y}
    [[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Deployment canceled"; exit 0; }
    
    gcloud services enable cloudbuild.googleapis.com run.googleapis.com iam.googleapis.com --quiet

    # ===== Clone repo =====
[[ -d "gcp-v2ray" ]] && rm -rf gcp-v2ray
git clone https://github.com/andrewzinkyaw/gcp-v2ray.git
cd gcp-v2ray

# ===== Build image =====
gcloud builds submit --tag gcr.io/${PROJECT_ID}/gcp-v2ray-image

# ===== Deploy Cloud Run =====
gcloud run deploy ${SERVICE_NAME} \
    --image gcr.io/${PROJECT_ID}/gcp-v2ray-image \
    --platform managed \
    --region ${REGION} \
    --allow-unauthenticated \
    --cpu ${CPU} \
    --memory ${MEMORY} \
    --quiet

    SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} --region ${REGION} --format 'value(status.url)' --quiet)
    DOMAIN=$(echo $SERVICE_URL | sed 's|https://||')

    START_TIME=$(TZ='Asia/Yangon' date +"%d-%m-%Y (%I:%M %p)")
    END_TIME=$(TZ='Asia/Yangon' date -d "+5 hours" +"%d-%m-%Y (%I:%M %p)")

    VLESS_LINK="vless://${UUID}@${HOST_DOMAIN}:443?path=%2Ftg-%40trenzych&security=tls&alpn=h3%2Ch2%2Chttp%2F1.1&encryption=none&host=${DOMAIN}&fp=randomized&type=ws&sni=${DOMAIN}#${SERVICE_NAME}"

    MESSAGE=$(cat <<EOF
<blockquote><b>MYTEL GCP VLESS Deployment</b></blockquote>
━━━━━━━━━━━━━━━━━━━━
📦<b> Service:</b> <code>${SERVICE_NAME}</code>
🌍<b> Region:</b> <code>${REGION}</code>
⚙️<b> Resource:</b> <code>${CPU} CPU | ${MEMORY} RAM</code>
🔗<b> Domain:</b> <code>${DOMAIN}</code>
━━━━━━━━━━━━━━━━━━━━
<blockquote><b>GCP V2Ray Access Key</b></blockquote>
<pre><code>${VLESS_LINK}</code></pre>
<blockquote>⏳<b> Start:</b> ${START_TIME}
⏰<b> End:</b>   ${END_TIME}</blockquote>
EOF
)
    echo "$MESSAGE" > deployment-info.txt
    info "Deployment info saved to deployment-info.txt"

    # === ✅ Console Summary ===
echo
echo -e "${BLUE}=== Deployment Summary (Console) ===${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Project:${NC} ${GREEN}${PROJECT_ID}${NC}"
echo -e "${YELLOW}Service:${NC} ${GREEN}${SERVICE_NAME}${NC}"
echo -e "${YELLOW}Region:${NC}  ${GREEN}${REGION}${NC}"
echo -e "${YELLOW}Resource:${NC} ${GREEN}${CPU} CPU | ${MEMORY} RAM${NC}"
echo -e "${YELLOW}Domain:${NC}  ${GREEN}${DOMAIN}${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${RED}VLESS LINK:${NC}"
echo -e "${GREEN}${VLESS_LINK}${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Start:${NC} ${GREEN}${START_TIME}${NC}"
echo -e "${YELLOW}End:  ${NC} ${GREEN}${END_TIME}${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
log "✅ Deployment completed successfully! 🎉🎉"
log "🌍 Service URL: ${GREEN}${SERVICE_URL}${NC}"

    if [[ "$TELEGRAM_DESTINATION" == "bot" || "$TELEGRAM_DESTINATION" == "both" ]]; then
        send_to_telegram "$TELEGRAM_CHAT_ID" "$MESSAGE" "bot"
    fi
    if [[ "$TELEGRAM_DESTINATION" == "channel" || "$TELEGRAM_DESTINATION" == "both" ]]; then
        send_to_telegram "$TELEGRAM_CHANNEL_ID" "$MESSAGE" "channel"
    fi
}

main "$@"
