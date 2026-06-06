import Foundation

/// 로컬라이제이션 리소스 번들.
/// `Bundle.module` 은 빌드 시점 절대경로(~/Documents/...)를 탐색 후보로 포함해
/// 배포 후에도 문서 폴더 접근(TCC) 알림을 유발하므로 사용하지 않는다.
/// 대신 실행 중인 앱 번들 옆의 리소스 번들을 직접 찾는다.
private let localizationBundle: Bundle = {
    if let url = Bundle.main.url(forResource: "FocusPlay_FocusPlay", withExtension: "bundle"),
       let bundle = Bundle(url: url) {
        return bundle
    }
    return .main
}()

/// 현재 시스템 언어에 맞는 문자열을 가져온다.
func L(_ key: String) -> String {
    NSLocalizedString(key, tableName: nil, bundle: localizationBundle, value: key, comment: "")
}
