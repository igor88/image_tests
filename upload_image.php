<?php

$target_path = "uploads/";
$target_path = $target_path.basename( $_FILES['input_image']['name']);
$res = move_uploaded_file($_FILES['input_image']['tmp_name'], $target_path);
if($res)
{
echo $target_path;
list($width, $height) = getimagesize($target_path);
echo ";".$width."-".$height;
}
else echo "error";


?>

