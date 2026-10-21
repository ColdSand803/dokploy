import { toast } from "sonner";
import { ToggleVisibilityInput } from "@/components/shared/toggle-visibility-input";
import { UpdateDatabasePassword } from "@/components/shared/update-database-password";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { api } from "@/utils/api";
import { useTranslation } from "@/lib/i18n";

interface Props {
	mysqlId: string;
}
export const ShowInternalMysqlCredentials = ({ mysqlId }: Props) => {
	const { t } = useTranslation();
	const { data } = api.mysql.one.useQuery({ mysqlId });
	const utils = api.useUtils();
	const { mutateAsync: changePassword } =
		api.mysql.changePassword.useMutation();
	return (
		<>
			<div className="flex w-full flex-col gap-5 ">
				<Card className="bg-background">
					<CardHeader>
						<CardTitle className="text-xl">{t("database.connection.internalCredentials")}</CardTitle>
					</CardHeader>
					<CardContent className="flex w-full flex-row gap-4">
						<div className="grid w-full md:grid-cols-2 gap-4 md:gap-8">
							<div className="flex flex-col gap-2">
								<Label>{t("database.connection.username")}</Label>
								<Input enableCopyButton disabled value={data?.databaseUser} />
							</div>
							<div className="flex flex-col gap-2">
								<Label>{t("database.connection.databaseName")}</Label>
								<Input enableCopyButton disabled value={data?.databaseName} />
							</div>
							<div className="flex flex-col gap-2">
								<Label>{t("database.connection.password")}</Label>
								<div className="flex flex-row gap-2 items-center">
									<ToggleVisibilityInput
										disabled
										value={data?.databasePassword}
									/>
									<UpdateDatabasePassword
										onUpdatePassword={async (newPassword) => {
											await changePassword({
												mysqlId,
												password: newPassword,
												type: "user",
											});
											toast.success(t("database.connection.passwordUpdated"));
											utils.mysql.one.invalidate({ mysqlId });
										}}
									/>
								</div>
							</div>
							<div className="flex flex-col gap-2">
								<Label>Root Password</Label>
								<div className="flex flex-row gap-2 items-center">
									<ToggleVisibilityInput
										disabled
										value={data?.databaseRootPassword}
									/>
									<UpdateDatabasePassword
										label="Root Password"
										onUpdatePassword={async (newPassword) => {
											await changePassword({
												mysqlId,
												password: newPassword,
												type: "root",
											});
											toast.success("Root password updated successfully");
											utils.mysql.one.invalidate({ mysqlId });
										}}
									/>
								</div>
							</div>
							<div className="flex flex-col gap-2">
								<Label>{t("database.connection.internalPort")}</Label>
								<Input disabled value="3306" />
							</div>

							<div className="flex flex-col gap-2">
								<Label>{t("database.connection.internalHost")}</Label>
								<Input enableCopyButton disabled value={data?.appName} />
							</div>

							<div className="flex flex-col gap-2 md:col-span-2">
								<Label>{t("database.connection.internalUrl")}</Label>
								<ToggleVisibilityInput
									disabled
									value={`mysql://${data?.databaseUser}:${data?.databasePassword}@${data?.appName}:3306/${data?.databaseName}`}
								/>
							</div>
						</div>
					</CardContent>
				</Card>
			</div>
		</>
	);
};
