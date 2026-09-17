import { setFromRoute } from "@/features/explorer/utils/utils";
import { DefaultRoute } from "@/utils/defaultRoutes";
import { useEffect } from "react";

export const useDefaultRoute = (defaultRoute: DefaultRoute) => {
  useEffect(() => {
    setFromRoute(defaultRoute);
  }, []);
};
