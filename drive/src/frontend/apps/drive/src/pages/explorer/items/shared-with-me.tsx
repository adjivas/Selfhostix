import { getGlobalExplorerLayout } from "@/features/layouts/components/explorer/ExplorerLayout";
import WorkspacesExplorer from "@/features/explorer/components/workspaces-explorer/WorkspacesExplorer";
import { DefaultRoute } from "@/utils/defaultRoutes";
import { useDefaultRoute } from "@/hooks/useDefaultRoute";

export default function SharedPage() {
  useDefaultRoute(DefaultRoute.SHARED_WITH_ME);
  return <WorkspacesExplorer defaultFilters={{ is_creator_me: false }} />;
}

SharedPage.getLayout = getGlobalExplorerLayout;
