import Foundation

/// config 파일의 `hotkey` 줄만 고친다.
///
/// 파일 전체를 다시 쓰지 않는 이유는 사용자가 손으로 쓴 파일이기 때문이다. 초안에서
/// 다시 만들면 주석과 줄 순서, 들여쓰기 취향이 전부 사라진다. 한 줄만 갈아 끼운다.
public enum HotkeyLine {
    private static let key = "hotkey:"
    private static let anchor = "workspace:"

    /// `hotkey`를 넣거나 바꾸거나(값이 있을 때) 지운다(nil일 때).
    ///
    /// 기존 줄이 있으면 그 자리를 유지한다. 없으면 `workspace:` 바로 아래에 넣는다.
    /// `workspace:`도 없으면 맨 앞에 넣는다. 그 파일은 어차피 파싱에 실패하지만,
    /// 사용자가 고치는 중일 수 있으므로 내용을 버리지 않는다.
    public static func apply(_ hotkey: String?, to yaml: String) -> String {
        var lines = yaml.components(separatedBy: "\n")

        if let index = lines.firstIndex(where: { isHotkey($0) }) {
            guard let hotkey else {
                lines.remove(at: index)
                return lines.joined(separator: "\n")
            }
            lines[index] = line(for: hotkey)
            return lines.joined(separator: "\n")
        }

        guard let hotkey else { return yaml }
        let insertion = lines.firstIndex { $0.hasPrefix(anchor) }.map { $0 + 1 } ?? 0
        lines.insert(line(for: hotkey), at: insertion)
        return lines.joined(separator: "\n")
    }

    /// 최상위 키만 본다. 들여쓴 `hotkey:`는 다른 뜻이므로 건드리지 않는다.
    private static func isHotkey(_ line: String) -> Bool {
        line.hasPrefix(key)
    }

    /// 값에 `+`가 들어가지만 YAML 평범한 스칼라로 안전하다. 그래도 따옴표를 씌우는 이유는
    /// 기존 예제와 모양을 맞추고, 사용자가 손으로 고칠 때 값의 경계가 보이게 하기 위해서다.
    private static func line(for hotkey: String) -> String {
        "\(key) \"\(hotkey)\""
    }
}
