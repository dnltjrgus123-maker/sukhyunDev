import "api_exception.dart";

String errorToMessage(Object error) {
  if (error is ApiException) {
    switch (error.statusCode) {
      case 400:
        return "요청 값이 올바르지 않습니다.";
      case 401:
        return "로그인이 필요합니다.";
      case 403:
        return "권한이 없습니다.";
      case 404:
        return "대상 정보를 찾을 수 없습니다.";
      case 409:
        return "현재 상태에서는 처리할 수 없습니다.";
      case 500:
      case 502:
      case 503:
        return "서버 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.";
      default:
        return error.message;
    }
  }
  return "알 수 없는 오류가 발생했습니다.";
}
