from diffusers import StableDiffusionXLPipeline, StableDiffusionXLImg2ImgPipeline
from .base_pipeline import ArtTicPipeline


class SDXLPipeline(ArtTicPipeline):
    def __init__(self, model_path, dtype=None):
        super().__init__(model_path, dtype)
        self.t2i_class = StableDiffusionXLPipeline
        self.i2i_class = StableDiffusionXLImg2ImgPipeline

    def load_pipeline(self, progress):
        progress(0.2, "Loading StableDiffusionXLPipeline...")
        self.pipe = self.t2i_class.from_single_file(
            self.model_path,
            torch_dtype=self.dtype,
            use_safetensors=True,
            variant="fp16",
            safety_checker=None,
            progress_bar_config={"disable": True},
        )
