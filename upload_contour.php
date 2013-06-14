<?php
$target_path = "contours/";
$image_name = $_POST["image_name"];
$fp=fopen($target_path.$image_name."_contour.txt","w");

#echo $target_path.$image_name."_contour.txt";

if($fp) {
  $t = json_decode($_POST["json"]);

  foreach($t as $point) {
    fwrite($fp,$point->x."\r\n");
    fwrite($fp,$point->y."\r\n");
  }

  fclose($fp);
  echo "true";
} else echo "false";
?>
