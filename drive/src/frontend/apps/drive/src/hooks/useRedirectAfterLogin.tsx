import { SESSION_STORAGE_REDIRECT_AFTER_LOGIN_URL } from "@/features/api/fetchApi";
import { useAuth } from "@/features/auth/Auth";
import { useEffect } from "react";

export const useRedirectAfterLogin = () => {
  const { user } = useAuth();
  // Redirect to the attempted url if it exists, otherwise redirect to the last visited item.
  useEffect(() => {
    if (user) {
      const attemptedUrl = sessionStorage.getItem(
        SESSION_STORAGE_REDIRECT_AFTER_LOGIN_URL,
      );
      if (attemptedUrl) {
        sessionStorage.removeItem(SESSION_STORAGE_REDIRECT_AFTER_LOGIN_URL);
        window.location.href = attemptedUrl;
      } else {
        window.location.href = `/explorer/items/my-files`;
      }
    }
  }, [user]);
};
