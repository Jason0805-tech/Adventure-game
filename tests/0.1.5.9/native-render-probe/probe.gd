extends SceneTree
func _initialize():
 call_deferred("run_probe")
func run_probe():
 var viewport := SubViewport.new()
 viewport.size = Vector2i(64, 64)
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 get_root().add_child(viewport)
 var rect := ColorRect.new()
 rect.size = Vector2(64,64)
 rect.color = Color(1,0,0,1)
 viewport.add_child(rect)
 for i in range(4):
  await process_frame
 RenderingServer.force_draw(false)
 var texture := viewport.get_texture()
 var pixels := texture.get_image()
 var report := {"display_server":DisplayServer.get_name(), "rendering_method":RenderingServer.get_current_rendering_method(), "rendering_driver":RenderingServer.get_current_rendering_driver_name(), "texture_size":[texture.get_width(), texture.get_height()], "image_null":pixels == null}
 if pixels != null:
  report["image_size"]=[pixels.get_width(),pixels.get_height()]
  report["image_empty"]=pixels.is_empty()
  if not pixels.is_empty():
   report["pixel_0_0"]=str(pixels.get_pixel(0,0))
   report["save_result"]=pixels.save_png("/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.5.9/native-render-probe/probe.png")
 print("NATIVE_RENDER_PROBE ",JSON.stringify(report))
 var out := FileAccess.open("/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.5.9/native-render-probe/report.json", FileAccess.WRITE)
 out.store_string(JSON.stringify(report,"  "))
 quit()
