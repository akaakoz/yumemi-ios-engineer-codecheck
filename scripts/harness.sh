#!/usr/bin/env bash
#
# ビルド・テストを、手元でも CI でも同じ手順で実行するためのスクリプト。
# 使い方は `scripts/harness.sh help` を参照。
#
# - 使うのは bash と Xcode に付属するコマンド（xcodebuild / xcrun）だけ
# - DerivedData・ログ・結果（.xcresult）はリポジトリ内の build/ に出し、端末ごとの場所に依存しない
# - 成否は終了コード（成功 0 / 失敗 1）で判断でき、失敗時は原因を調べるための情報を表示する

set -uo pipefail

# Apple Silicon の Mac で Rosetta（x86_64）として実行された場合は、arm64 で実行し直す。
# SwiftLint（ビルドツールプラグイン）が x86_64 で起動すると、Xcode の arm64 用ライブラリを読み込めずに失敗するため
if [ "$(sysctl -n sysctl.proc_translated 2>/dev/null)" = "1" ]; then
    exec arch -arm64 /bin/bash "$0" "$@"
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="iOSEngineerCodeCheck.xcodeproj"
SCHEME="iOSEngineerCodeCheck"
UNIT_TEST_TARGET="iOSEngineerCodeCheckTests"
UI_TEST_TARGET="iOSEngineerCodeCheckUITests"

# 実行するシミュレータ。端末にあるシミュレータに合わせて環境変数で上書きできる
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=latest}"

BUILD_DIR="$ROOT_DIR/build"
DERIVED_DATA_DIR="$BUILD_DIR/DerivedData"
OUTPUT_DIR="$BUILD_DIR/harness"

usage() {
    cat <<'EOF'
使い方: scripts/harness.sh <コマンド>

  check   変更後に毎回実行する: lint → build → unit
  all     check に加えて UI テストも実行する（CI で使う）
  lint    プロジェクトのルールで禁止しているコードの書き方を検出する
  build   アプリとテストをビルドする（警告もエラーとして扱う）
  unit    ユニットテストを実行する（build の後に実行する）
  ui      UI テストを実行する（build の後に実行する）
  help    この説明を表示する

環境変数:
  DESTINATION  実行するシミュレータ（既定: platform=iOS Simulator,name=iPhone 17,OS=latest）

結果: 成功なら終了コード 0、失敗なら 1。
ログと結果は build/harness/<ステップ名>.log と build/harness/<ステップ名>.xcresult に出力する。
EOF
}

log() {
    printf '[harness] %s\n' "$*"
}

# xcodebuild を実行し、ログと .xcresult を build/harness/ に残す。
# 引数: <ステップ名> <xcodebuild のアクションとオプション...>
run_xcodebuild() {
    local step="$1"
    shift
    local log_file="$OUTPUT_DIR/$step.log"
    local result_bundle="$OUTPUT_DIR/$step.xcresult"

    mkdir -p "$OUTPUT_DIR"
    # 同じパスに .xcresult があると xcodebuild が失敗するため、前回の結果を消す
    rm -rf "$result_bundle"

    log "$step: 実行中（ログ: build/harness/$step.log）"
    local started_at=$SECONDS
    (
        cd "$ROOT_DIR" &&
            xcodebuild \
                -project "$PROJECT" \
                -scheme "$SCHEME" \
                -destination "$DESTINATION" \
                -derivedDataPath "$DERIVED_DATA_DIR" \
                -resultBundlePath "$result_bundle" \
                "$@"
    ) >"$log_file" 2>&1
    local status=$?
    local elapsed=$((SECONDS - started_at))

    if [ "$status" -eq 0 ]; then
        log "$step: 成功（${elapsed}秒）"
        print_test_counts "$result_bundle"
        return 0
    fi

    log "$step: 失敗（${elapsed}秒、xcodebuild の終了コード ${status}）"
    print_diagnostics "$step" "$log_file" "$result_bundle"
    return 1
}

# テストの件数を表示する。テストを実行しないステップ（build）では何も表示しない。
print_test_counts() {
    local result_bundle="$1"
    local summary
    summary="$(read_test_summary "$result_bundle")" || return 0
    local total
    total="$(json_value "$summary" totalTestCount)" || return 0
    [ "$total" -gt 0 ] 2>/dev/null || return 0
    log "  テスト: 成功 $(json_value "$summary" passedTests) / 失敗 $(json_value "$summary" failedTests) / スキップ $(json_value "$summary" skippedTests)（全 ${total} 件）"
    log "  実行環境: $(device_description "$summary")"
}

# テストを実行したシミュレータの名前と OS（例: iPhone 17 / iOS 26.5）。シミュレータの違いによる失敗を見分けるために表示する。
device_description() {
    local summary="$1"
    local name os
    name="$(json_value "$summary" devicesAndConfigurations.0.device.deviceName)" || name="不明"
    os="$(json_value "$summary" devicesAndConfigurations.0.device.osVersion)" || os="不明"
    printf '%s / iOS %s' "$name" "$os"
}

# 失敗の原因を調べるための情報を表示する。
print_diagnostics() {
    local step="$1"
    local log_file="$2"
    local result_bundle="$3"

    if grep -q -E "Unable to find a (device|destination) matching" "$log_file"; then
        log "指定されたシミュレータが見つかりません: $DESTINATION"
        log "環境変数 DESTINATION で、次のいずれかを指定してください（例: DESTINATION='platform=iOS Simulator,name=<名前>,OS=<バージョン>'）"
        # このスキームを実行できる（デプロイメントターゲットを満たす）iPhone のシミュレータだけを表示する
        (cd "$ROOT_DIR" && xcodebuild -showdestinations -project "$PROJECT" -scheme "$SCHEME" 2>/dev/null) |
            grep "platform:iOS Simulator" | grep "name:iPhone" | sed -E 's/^[[:space:]]*/  /' | head -30
        return
    fi

    local summary
    if summary="$(read_test_summary "$result_bundle")"; then
        local failure_count
        failure_count="$(json_value "$summary" testFailures)" || failure_count=0
        if [ "$failure_count" -gt 0 ] 2>/dev/null; then
            log "失敗したテスト（${failure_count} 件、実行環境: $(device_description "$summary")）:"
            local index=0
            while [ "$index" -lt "$failure_count" ]; do
                local target name identifier
                target="$(json_value "$summary" "testFailures.$index.targetName")"
                name="$(json_value "$summary" "testFailures.$index.testName")"
                identifier="$(json_value "$summary" "testFailures.$index.testIdentifierString")"
                if [ -n "$identifier" ] && [ "${identifier%/"$name"}" != "$identifier" ]; then
                    # XCTest は表示名がメソッド名で、関数名が「クラス名/メソッド名」になるため、関数名だけを表示する
                    log "  - $target/$identifier"
                elif [ -n "$identifier" ] && [ "$identifier" != "$name" ]; then
                    # Swift Testing の表示名だけでは関数を探しにくいため、関数名も併記する
                    log "  - ${target}/${name}（${identifier}）"
                else
                    log "  - $target/$name"
                fi
                json_value "$summary" "testFailures.$index.failureText" | sed 's/^/        /'
                index=$((index + 1))
            done
        fi
    fi

    # 失敗した箇所（ファイル:行）は xcresult の要約に含まれないため、ログから抜き出す。
    # Swift Testing は「recorded an issue at <ファイル>:<行>」の形で出力する。
    # XCTest（UI テスト）は「<ファイル>:<行>: error: ...」の形で出力し、下のエラーの抜き出しで表示される
    local locations
    locations="$(grep -F "recorded an issue at" "$log_file" | sed -E 's/^[[:space:]]*//' | sort -u | head -20)"
    if [ -n "$locations" ]; then
        log "失敗した箇所（ログより、最大 20 行）:"
        printf '%s\n' "$locations" | sed 's/^/  /'
    fi

    # コンパイルエラーや警告（警告もエラーとして扱っている）、テストの実行自体の失敗
    local issues
    issues="$(grep -E "(error|warning): " "$log_file" | sort -u | head -40)"
    if [ -n "$issues" ]; then
        log "ログ中のエラー・警告（最大 40 行）:"
        printf '%s\n' "$issues"
    fi

    log "詳細: ログ build/harness/$step.log"
    if [ -d "$result_bundle" ]; then
        log "      結果 build/harness/$step.xcresult（Xcode で開くと、UI テストの失敗時の画面なども確認できる: open build/harness/$step.xcresult）"
    fi
}

# .xcresult からテスト結果の要約（JSON）を読み出す。テスト結果がなければ失敗を返す。
read_test_summary() {
    local result_bundle="$1"
    [ -d "$result_bundle" ] || return 1
    xcrun xcresulttool get test-results summary --path "$result_bundle" 2>/dev/null
}

# JSON から値を取り出す。配列を指定した場合は要素数を返す。
# 引数: <JSON> <キーパス（例: testFailures.0.testName）>
json_value() {
    printf '%s' "$1" | plutil -extract "$2" raw -o - - 2>/dev/null
}

# プロジェクトのルールで禁止している書き方。「<正規表現（awk）>	<説明>」を1行に1つ書く。
FORBIDDEN_PATTERNS='try[?]	try? でエラーを握りつぶさない。do-catch で扱う
try!	try! は使わない。do-catch で扱う
as!	as! は使わない。as? で扱う
catch[^{]*[{][[:space:]]*[}]	空の catch でエラーを握りつぶさない
@unchecked[[:space:]]+Sendable	@unchecked Sendable は使わない。Sendable を満たす型にする
nonisolated[(]unsafe[)]	nonisolated(unsafe) は使わない
Task[.]sleep	Task.sleep で待ち合わせない（テストでも使わない）。完了を待てる仕組みにする'

# lint の対象にする Swift ファイルを、NUL 区切りで出力する。
# git で管理しているファイルと、gitignore の対象外の未追加ファイルが対象。
# git rm せずに削除したファイルは git の一覧に残るため、ディスク上に存在するものだけに絞る
list_swift_files() {
    local file
    git ls-files -z --cached --others --exclude-standard '*.swift' |
        while IFS= read -r -d '' file; do
            if [ -f "$file" ]; then
                printf '%s\0' "$file"
            fi
        done
}

# 対象の Swift ファイルから、禁止している書き方を検出する。
# - コメント（// 以降）は対象外
# - やむを得ず使う行には「// harness:allow <理由>」を書くと対象外になる
step_lint() {
    log "lint: 実行中"
    local started_at=$SECONDS
    local violations
    violations="$(
        cd "$ROOT_DIR" &&
            list_swift_files |
            HARNESS_FORBIDDEN_PATTERNS="$FORBIDDEN_PATTERNS" xargs -0 awk '
                BEGIN {
                    count = split(ENVIRON["HARNESS_FORBIDDEN_PATTERNS"], lines, "\n")
                    for (i = 1; i <= count; i++) {
                        split(lines[i], fields, "\t")
                        regex[i] = fields[1]
                        message[i] = fields[2]
                    }
                }
                index($0, "harness:allow") > 0 { next }
                {
                    code = $0
                    comment_start = index(code, "//")
                    if (comment_start > 0) {
                        code = substr(code, 1, comment_start - 1)
                    }
                    for (i = 1; i <= count; i++) {
                        if (code ~ regex[i]) {
                            printf "%s:%d: %s\n    %s\n", FILENAME, FNR, message[i], $0
                        }
                    }
                }
            '
    )"
    local status=$?
    local elapsed=$((SECONDS - started_at))

    # 検査そのものが失敗した場合（awk のエラーなど）は、検出なしと誤って判断しないよう失敗にする
    if [ "$status" -ne 0 ]; then
        log "lint: 失敗（${elapsed}秒、検査を実行できませんでした。終了コード ${status}）"
        return 1
    fi

    if [ -z "$violations" ]; then
        log "lint: 成功（${elapsed}秒）"
        return 0
    fi

    log "lint: 失敗（${elapsed}秒）"
    log "禁止している書き方が見つかりました（<ファイル>:<行>: <理由>）:"
    printf '%s\n' "$violations"
    log "やむを得ず使う場合は、その行に「// harness:allow <理由>」を書いてください"
    return 1
}

step_build() {
    # 警告もエラーとして扱い、Swift 6 の並行処理の警告などを取りこぼさない。
    # project の設定は変えず、このスクリプトで実行するときだけ指定する。
    # シミュレータ向けのため署名はしない（個人の開発チームに依存しない）。
    # SwiftLint（SwiftLintBuildToolPlugin）はビルドの中で実行される。
    # - Package.resolved のバージョンだけを使い、手元と CI で同じ SwiftLint にする
    # - コマンドからのビルドでは、Xcode で行う「プラグインを信頼する」操作ができないため、確認を省く
    run_xcodebuild build build-for-testing \
        -onlyUsePackageVersionsFromResolvedFile \
        -skipPackagePluginValidation \
        SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
        GCC_TREAT_WARNINGS_AS_ERRORS=YES \
        CODE_SIGNING_ALLOWED=NO
}

step_unit() {
    run_xcodebuild unit test-without-building -only-testing:"$UNIT_TEST_TARGET"
}

step_ui() {
    run_xcodebuild ui test-without-building -only-testing:"$UI_TEST_TARGET"
}

# ステップを順に実行し、最初に失敗したところで止める。
run_steps() {
    local step
    for step in "$@"; do
        if ! "step_$step"; then
            log "結果: 失敗（${step}）"
            return 1
        fi
    done
    log "結果: 成功（$*）"
    return 0
}

main() {
    local command="${1:-check}"
    case "$command" in
        check) run_steps lint build unit ;;
        all) run_steps lint build unit ui ;;
        lint | build | unit | ui) run_steps "$command" ;;
        help | -h | --help) usage ;;
        *)
            usage >&2
            return 1
            ;;
    esac
}

main "$@"
