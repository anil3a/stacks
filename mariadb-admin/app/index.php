<!DOCTYPE html>
<html lang="en">
<!-- Author: Anil Prajapati @anilprz -->
<!-- Adapted from github.com/anil3a/simple-phpadminer-mariadb-docker:
     root credentials come from env (DB_HOST / MARIADB_ROOT_PASSWORD), names are validated,
     the password is quoted and output is escaped. -->

<head>
	<meta charset="UTF-8">
	<title>Database Manager</title>
	<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-QWTKZyjpPEjISv5WaRU9OFeRpok6YctnYmDr5pNlyT2bRjXh0JMhjY6hW+ALEwIH" crossorigin="anonymous">
	<style>
		body {
			display: flex;
			justify-content: center;
			align-items: center;
			background-color: #f8f9fa;
			padding-top: 5%;
		}

		.form-group {
			margin-bottom: 2em;
		}

		.card {
			width: 100%;
			max-width: 800px;
			margin-top: 20px;
		}
	</style>
</head>

<body>
	<div class="card">
		<div class="card-body">
			<h4 class="card-title text-center mb-4">Create Database and User</h4>
			<form action="" method="post">
				<div class="form-group">
					<label for="db_name">Database Name:</label>
					<input type="text" id="db_name" name="db_name" class="form-control" pattern="[A-Za-z0-9_]{1,64}" required>
				</div>

				<div class="form-group">
					<label for="db_user">Username:</label>
					<input type="text" id="db_user" name="db_user" class="form-control" pattern="[A-Za-z0-9_]{1,64}" required>
				</div>

				<div class="form-group">
					<label for="db_pass">Password:</label>
					<input type="password" id="db_pass" name="db_pass" class="form-control" required>
				</div>

				<button type="submit" name="create" class="btn btn-primary btn-block">Create Database and User</button>
			</form>

			<?php
			if (isset($_POST['create'])) {
				$host = getenv('DB_HOST') ?: 'mariadb';
				$rootUser = 'root';
				$rootPassword = getenv('MARIADB_ROOT_PASSWORD');
				$dbName = $_POST['db_name'] ?? '';
				$dbUser = $_POST['db_user'] ?? '';
				$dbPass = $_POST['db_pass'] ?? '';
				$h = fn($s) => htmlspecialchars($s, ENT_QUOTES);

				if (!preg_match('/^[A-Za-z0-9_]{1,64}$/', $dbName) || !preg_match('/^[A-Za-z0-9_]{1,64}$/', $dbUser)) {
					echo "<div class='alert alert-danger mt-4'>Database name and username may only contain letters, digits and underscores (max 64).</div>";
				} else {
					try {
						$pdo = new PDO("mysql:host=$host", $rootUser, $rootPassword);
						$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

						$pdo->exec("CREATE DATABASE IF NOT EXISTS `$dbName`");
						echo "<div class='alert alert-success mt-4'>Database '{$h($dbName)}' created successfully.</div>";

						$pdo->exec("CREATE USER IF NOT EXISTS '$dbUser'@'%' IDENTIFIED BY " . $pdo->quote($dbPass));
						$pdo->exec("GRANT ALL PRIVILEGES ON `$dbName`.* TO '$dbUser'@'%'");
						$pdo->exec("FLUSH PRIVILEGES");
						echo "<div class='alert alert-success'>User '{$h($dbUser)}' created and granted privileges on '{$h($dbName)}'.</div>";
					} catch (PDOException $e) {
						echo "<div class='alert alert-danger mt-4'>Error: " . $h($e->getMessage()) . "</div>";
					}
					$pdo = null;
				}
			}
			?>
		</div>
	</div>
</body>

</html>
